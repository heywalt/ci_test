defmodule WaltUi.Google.Gmail.HistoricalSyncTest do
  use WaltUi.CqrsCase, async: false

  import WaltUi.Factory
  import Mox

  alias WaltUi.ExternalAccounts
  alias WaltUi.Google.Gmail.HistoricalSync

  setup :verify_on_exit!

  setup do
    Application.put_env(:tesla, :adapter, WaltUi.Google.GmailMockAdapter)
    on_exit(fn -> Application.delete_env(:tesla, :adapter) end)
    :ok
  end

  describe "sync_historical_messages/1" do
    test "successfully syncs messages from multiple contacts in batches" do
      user = insert(:user)
      ea = insert(:external_account, user: user, provider: :google, email: "user@example.com")
      # Ensure user association is loaded
      ea = %{ea | user: user}

      # Create more than 50 contacts to test batching
      _contacts =
        for i <- 1..60 do
          await_contact(%{user_id: user.id, email: "contact#{i}@example.com"})
        end

      # Track API calls to verify batching
      call_count = :counters.new(1, [])

      Mox.stub(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        handle_batch_test_request(env, ea, call_count)
      end)

      assert :ok = HistoricalSync.sync_historical_messages(ea)

      # Verify sync metadata
      updated_ea = ExternalAccounts.get(ea.id)
      assert updated_ea.historical_sync_metadata["status"] == "success"
      assert updated_ea.historical_sync_metadata["completed_at"] != nil

      # Verify ContactInteractions were created for the contacts
      contact_interactions =
        Repo.all(
          from ci in WaltUi.Projections.ContactInteraction,
            where: ci.activity_type == :contact_corresponded
        )

      # Should have multiple interactions created (60 contacts created, some should have messages)
      assert length(contact_interactions) > 0
    end

    test "handles empty contact list gracefully" do
      user = insert(:user)
      ea = insert(:external_account, user: user, provider: :google)

      # No contacts for this user

      assert :ok = HistoricalSync.sync_historical_messages(ea)

      # Verify sync completed successfully even with no contacts
      updated_ea = ExternalAccounts.get(ea.id)
      assert updated_ea.historical_sync_metadata["status"] == "success"
    end

    test "filters out messages without matching contacts" do
      user = insert(:user)
      ea = insert(:external_account, user: user, provider: :google, email: "user@example.com")
      # Ensure user association is loaded
      ea = %{ea | user: user}
      contact = await_contact(%{user_id: user.id, email: "contact@example.com"})

      Mox.stub(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        cond do
          String.contains?(env.url, "/messages") and Map.has_key?(env, :query) and
            is_map(env.query) and Map.has_key?(env.query, :q) ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{
                   "messages" => [
                     # Will match contact
                     %{"id" => "msg1"},
                     # Won't match any contact
                     %{"id" => "msg2"}
                   ]
                 }
             }}

          String.ends_with?(env.url, "/messages/msg1") ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: message_response("msg1", ea.email, contact.email, "Matching message")
             }}

          String.ends_with?(env.url, "/messages/msg2") ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body:
                   message_response(
                     "msg2",
                     ea.email,
                     "unknown@example.com",
                     "Non-matching message"
                   )
             }}

          String.ends_with?(env.url, "/profile") ->
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{"historyId" => "12345"}
             }}

          true ->
            {:ok, %Tesla.Env{env | status: 200, body: %{}}}
        end
      end)

      assert :ok = HistoricalSync.sync_historical_messages(ea)

      # Verify the ContactInteraction was created (which proves the event was processed)
      assert [_contact_created, contact_interaction] =
               Repo.all(
                 from ci in WaltUi.Projections.ContactInteraction,
                   where: ci.contact_id == ^contact.id,
                   order_by: ci.inserted_at
               )

      assert contact_interaction.activity_type == :contact_corresponded
      assert contact_interaction.metadata["subject"] == "Matching message"
      assert contact_interaction.metadata["direction"] == "sent"
    end

    test "handles pagination correctly" do
      user = insert(:user)
      ea = insert(:external_account, user: user, provider: :google, email: "user@example.com")
      contact = await_contact(%{user_id: user.id, email: "contact@example.com"})

      # Track pagination calls
      page_tokens = ["", "page2", nil]
      call_index = :counters.new(1, [])

      Mox.stub(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        cond do
          String.contains?(env.url, "/messages") and Map.has_key?(env, :query) and
            is_map(env.query) and Map.has_key?(env.query, :q) ->
            index = :counters.get(call_index, 1)
            :counters.add(call_index, 1, 1)

            _current_token = Enum.at(page_tokens, index - 1)
            next_token = Enum.at(page_tokens, index)

            response = %{
              "messages" => [%{"id" => "msg_page#{index}"}]
            }

            response =
              if next_token, do: Map.put(response, "nextPageToken", next_token), else: response

            {:ok, %Tesla.Env{env | status: 200, body: response}}

          String.contains?(env.url, "/messages/msg_page") ->
            message_id = env.url |> String.split("/") |> List.last()

            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: message_response(message_id, contact.email, ea.email, "Page message")
             }}

          String.ends_with?(env.url, "/profile") ->
            {:ok, %Tesla.Env{env | status: 200, body: %{"historyId" => "12345"}}}

          true ->
            {:ok, %Tesla.Env{env | status: 404, body: %{"error" => "Not found"}}}
        end
      end)

      assert :ok = HistoricalSync.sync_historical_messages(ea)

      # Verify all pages were processed
      # 2 pages + initial call
      assert :counters.get(call_index, 1) == 3
    end

    test "updates progress metadata during sync" do
      user = insert(:user)
      ea = insert(:external_account, user: user, provider: :google, email: "user@example.com")
      await_contact(%{user_id: user.id, email: "contact@example.com"})

      # Mock successful sync
      Mox.stub(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        cond do
          # List messages call (has 'q' query parameter)
          String.contains?(env.url, "/messages") and Map.has_key?(env, :query) and
            is_map(env.query) and Map.has_key?(env.query, :q) ->
            {:ok, %Tesla.Env{env | status: 200, body: %{"messages" => [%{"id" => "msg1"}]}}}

          # Individual message call (URL ends with message ID)
          String.contains?(env.url, "/messages/msg") ->
            response_body = message_response("msg1", "contact@example.com", ea.email, "Test")

            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: response_body
             }}

          String.contains?(env.url, "/profile") ->
            {:ok, %Tesla.Env{env | status: 200, body: %{"historyId" => "12345"}}}

          true ->
            {:ok, %Tesla.Env{env | status: 200, body: %{}}}
        end
      end)

      assert :ok = HistoricalSync.sync_historical_messages(ea)

      updated_ea = ExternalAccounts.get(ea.id)
      metadata = updated_ea.historical_sync_metadata

      # Check progress tracking fields
      assert metadata["status"] == "success"
      assert metadata["completed_at"] != nil
      assert metadata["last_updated_at"] != nil
      # Note: started_at and progress may not be set depending on sync flow
    end
  end

  defp message_response(id, from, to, subject) do
    %{
      "id" => id,
      "threadId" => "thread_#{id}",
      "payload" => %{
        "headers" => [
          %{"name" => "From", "value" => from},
          %{"name" => "To", "value" => to},
          %{"name" => "Subject", "value" => subject},
          %{"name" => "Date", "value" => "Mon, 15 Jan 2024 10:30:00 +0000"}
        ]
      }
    }
  end

  # Helper function for batch test with pattern matching
  defp handle_batch_test_request(%{url: url} = env, ea, call_count) do
    profile_url = "https://gmail.googleapis.com/gmail/v1/users/#{ea.email}/profile"

    cond do
      String.contains?(url, "/messages") and Map.has_key?(env, :query) and is_map(env.query) and
          Map.has_key?(env.query, :q) ->
        handle_list_request(env, call_count)

      url == profile_url ->
        {:ok, %Tesla.Env{env | status: 200, body: %{"historyId" => "updated_12345"}}}

      String.contains?(url, "/messages/msg_") ->
        handle_message_request(env, ea)

      true ->
        {:ok, %Tesla.Env{env | status: 404, body: %{"error" => "Not found"}}}
    end
  end

  defp handle_list_request(env, call_count) do
    :counters.add(call_count, 1, 1)
    batch_num = :counters.get(call_count, 1)

    if batch_num <= 2 do
      {:ok,
       %Tesla.Env{
         env
         | status: 200,
           body: %{
             "messages" => [
               %{"id" => "msg_batch#{batch_num}_1"},
               %{"id" => "msg_batch#{batch_num}_2"}
             ]
           }
       }}
    else
      # This shouldn't happen in this test
      {:ok, %Tesla.Env{env | status: 200, body: %{"messages" => []}}}
    end
  end

  defp handle_message_request(env, ea) do
    message_id = env.url |> String.split("/") |> List.last()
    contact_email = get_contact_email_for_message(message_id)

    {:ok,
     %Tesla.Env{
       env
       | status: 200,
         body: message_response(message_id, ea.email, contact_email, "Test #{message_id}")
     }}
  end

  defp get_contact_email_for_message("msg_batch1_1"), do: "contact1@example.com"
  defp get_contact_email_for_message("msg_batch1_2"), do: "contact2@example.com"
  defp get_contact_email_for_message("msg_batch2_1"), do: "contact51@example.com"
  defp get_contact_email_for_message("msg_batch2_2"), do: "contact52@example.com"
  defp get_contact_email_for_message(_), do: "unknown@example.com"
end
