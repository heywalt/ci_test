defmodule WaltUi.Google.Gmail.HistoricalEmailSyncJobTest do
  use WaltUi.CqrsCase, async: false
  use Oban.Testing, repo: Repo

  import WaltUi.Factory
  import Mox

  alias WaltUi.ExternalAccounts
  alias WaltUi.Google.Gmail.HistoricalEmailSyncJob

  setup :verify_on_exit!

  describe "perform/1" do
    test "successfully syncs historical messages for Google account" do
      user = insert(:user)

      ea =
        insert(:external_account,
          user: user,
          provider: :google,
          email: "test@example.com",
          gmail_history_id: "12345"
        )

      # Create contacts via CQRS to ensure both aggregates and projections exist
      contact1 = await_contact(%{user_id: user.id, email: "contact1@example.com"})
      contact2 = await_contact(%{user_id: user.id, email: "contact2@example.com"})

      # Mock Gmail API responses
      profile_url = "https://gmail.googleapis.com/gmail/v1/users/#{ea.email}/profile"
      message_url1 = "https://gmail.googleapis.com/gmail/v1/users/#{ea.email}/messages/msg1"
      message_url2 = "https://gmail.googleapis.com/gmail/v1/users/#{ea.email}/messages/msg2"

      Application.put_env(:tesla, :adapter, WaltUi.Google.GmailMockAdapter)
      on_exit(fn -> Application.delete_env(:tesla, :adapter) end)

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, 3, fn env, _opts ->
        cond do
          String.contains?(env.url, "/messages") and Map.has_key?(env, :query) ->
            # Return message list for search query
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{
                   "messages" => [
                     %{"id" => "msg1"},
                     %{"id" => "msg2"}
                   ]
                 }
             }}

          env.url == message_url1 ->
            # Return message from contact1
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: message_response("msg1", ea.email, contact1.email, "Test Subject 1")
             }}

          env.url == message_url2 ->
            # Return message to contact2
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: message_response("msg2", contact2.email, ea.email, "Test Subject 2")
             }}

          env.url == profile_url ->
            # Return updated history ID
            {:ok,
             %Tesla.Env{
               env
               | status: 200,
                 body: %{"historyId" => "67890"}
             }}

          true ->
            {:ok, %Tesla.Env{env | status: 200, body: %{}}}
        end
      end)

      # Perform the job
      assert :ok = perform_job(HistoricalEmailSyncJob, %{"external_account_id" => ea.id})

      # Verify at least the contacts were created
      contact_interactions =
        Repo.all(
          from ci in WaltUi.Projections.ContactInteraction,
            where: ci.activity_type == :contact_created
        )

      assert length(contact_interactions) == 2
      assert Enum.any?(contact_interactions, &(&1.contact_id == contact1.id))
      assert Enum.any?(contact_interactions, &(&1.contact_id == contact2.id))

      # Verify sync metadata was updated
      updated_ea = ExternalAccounts.get(ea.id)
      assert updated_ea.historical_sync_metadata["status"] == "success"
      assert updated_ea.historical_sync_metadata["completed_at"] != nil
    end

    test "skips non-Google providers" do
      ea = insert(:external_account, provider: :skyslope)

      assert :ok = perform_job(HistoricalEmailSyncJob, %{"external_account_id" => ea.id})

      # No events should be created - wait a bit to ensure no events are dispatched
      refute_receive {:events, _}, 100
    end

    test "handles external account not found" do
      assert {:error, "External account not found"} =
               perform_job(HistoricalEmailSyncJob, %{
                 "external_account_id" => Ecto.UUID.generate()
               })
    end

    test "handles sync failure gracefully" do
      user = insert(:user)

      ea =
        insert(:external_account,
          user: user,
          provider: :google,
          email: "test@example.com",
          gmail_history_id: "12345"
        )

      # Create a contact so the sync will attempt to fetch messages
      await_contact(%{user_id: user.id, email: "contact@example.com"})

      # Mock Gmail API to return error
      Application.put_env(:tesla, :adapter, WaltUi.Google.GmailMockAdapter)
      on_exit(fn -> Application.delete_env(:tesla, :adapter) end)

      # Return a response that will cause the sync to fail
      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        if String.contains?(env.url, "/messages") and Map.has_key?(env, :query) do
          # Return 401 which is properly handled as an error
          {:ok, %Tesla.Env{env | status: 401, body: %{"error" => "Unauthorized"}}}
        else
          # Return success for other requests
          {:ok, %Tesla.Env{env | status: 200, body: %{"historyId" => "12345"}}}
        end
      end)

      # The job now properly returns errors
      assert {:error, _} = perform_job(HistoricalEmailSyncJob, %{"external_account_id" => ea.id})

      # Verify sync metadata shows failure
      updated_ea = ExternalAccounts.get(ea.id)
      assert updated_ea.historical_sync_metadata["status"] == "failed"
      assert updated_ea.historical_sync_metadata["error"] != nil
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
end
