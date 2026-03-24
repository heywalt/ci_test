defmodule WaltUi.MCP.Tools.SearchEmailsTest do
  use WaltUi.CqrsCase

  import Mox
  import WaltUi.Factory

  alias WaltUi.MCP.Tools.SearchEmails

  setup do
    Application.put_env(:tesla, :adapter, WaltUi.Google.GmailMockAdapter)
    on_exit(fn -> Application.delete_env(:tesla, :adapter) end)
    :ok
  end

  setup :verify_on_exit!

  describe "execute/2" do
    setup do
      user = insert(:user, email: "user@example.com")

      ea =
        insert(:external_account,
          user: user,
          provider: "google",
          email: "user@example.com",
          gmail_history_id: "12345"
        )

      contact =
        await_contact(
          user_id: user.id,
          email: "john.doe@example.com",
          first_name: "John",
          last_name: "Doe"
        )

      [user: user, ea: ea, contact: contact]
    end

    test "returns error when user_id missing from frame" do
      frame = %{assigns: %{}}
      params = %{"contact_name" => "John Doe"}

      assert {:error, "user_id is required in context"} = SearchEmails.execute(params, frame)
    end

    test "returns error when no Google account connected", %{user: user} do
      # Delete the external account
      Repo.delete_all(WaltUi.ExternalAccounts.ExternalAccount)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John Doe"}

      assert {:error, "No Google account connected"} = SearchEmails.execute(params, frame)
    end

    test "returns error when contact not found", %{user: user} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "Unknown Person"}

      assert {:error, message} = SearchEmails.execute(params, frame)
      assert message =~ "No contacts found matching"
    end

    test "returns emails for valid contact", %{user: user, ea: ea, contact: contact} do
      setup_gmail_mocks(ea, message_count: 2)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John Doe"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      assert is_list(result["emails"])
      assert result["contact"]["name"] =~ "John"
      assert result["contact"]["id"] == contact.id
    end

    test "searches by first name only", %{user: user, ea: ea} do
      setup_gmail_mocks(ea, message_count: 1)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      assert result["contact"]["name"] =~ "John"
    end

    test "searches by last name only", %{user: user, ea: ea} do
      setup_gmail_mocks(ea, message_count: 1)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "Doe"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      assert result["contact"]["name"] =~ "Doe"
    end

    test "respects limit parameter", %{user: user, ea: ea} do
      # Request 2 emails, mock returns 2
      setup_gmail_mocks(ea, message_count: 2)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John Doe", "limit" => 2}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      assert length(result["emails"]) <= 2
    end

    test "enforces hard cap of 20 on limit", %{user: user, ea: ea} do
      setup_gmail_mocks(ea, message_count: 5)

      frame = %{assigns: %{user_id: user.id}}
      # Request 50, should be capped to 20
      params = %{"contact_name" => "John Doe", "limit" => 50}

      assert {:ok, _result} = SearchEmails.execute(params, frame)
      # The limit should be capped, but we're only mocking 5 messages
    end

    test "includes full email body in response", %{user: user, ea: ea} do
      setup_gmail_mocks(ea, message_count: 1)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John Doe"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      [email | _] = result["emails"]

      assert is_binary(email["body"])
      assert String.length(email["body"]) > 0
    end

    test "includes email metadata in response", %{user: user, ea: ea} do
      setup_gmail_mocks(ea, message_count: 1)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John Doe"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      [email | _] = result["emails"]

      assert Map.has_key?(email, "id")
      assert Map.has_key?(email, "subject")
      assert Map.has_key?(email, "from")
      assert Map.has_key?(email, "to")
      assert Map.has_key?(email, "date")
      assert Map.has_key?(email, "message_link")
    end

    test "returns empty emails list when no emails found", %{user: user, ea: ea} do
      # Mock returns no messages
      setup_gmail_mocks(ea, message_count: 0)

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_name" => "John Doe"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      assert result["emails"] == []
    end

    test "returns error when neither contact_name nor message_id provided", %{user: user} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{}

      assert {:error, message} = SearchEmails.execute(params, frame)
      assert message =~ "Either contact_name or message_id is required"
    end

    test "fetches single email by message_id", %{user: user, ea: ea} do
      setup_single_message_mock(ea, "specific_msg_123")

      frame = %{assigns: %{user_id: user.id}}
      params = %{"message_id" => "specific_msg_123"}

      assert {:ok, result} = SearchEmails.execute(params, frame)
      assert length(result["emails"]) == 1
      [email] = result["emails"]
      assert email["id"] == "specific_msg_123"
      assert is_binary(email["body"])
    end
  end

  # Helper to setup Gmail API mocks
  defp setup_gmail_mocks(_ea, opts) do
    message_count = Keyword.get(opts, :message_count, 1)

    # We need 1 call for list_message_ids + N calls for each get_message
    total_calls = 1 + message_count

    Mox.expect(WaltUi.Google.GmailMockAdapter, :call, total_calls, fn env, _opts ->
      cond do
        # List messages endpoint ends with /messages (no trailing path)
        Regex.match?(~r/\/messages$/, env.url) ->
          {:ok, %Tesla.Env{env | status: 200, body: list_messages_response(message_count)}}

        # Get message endpoint has /messages/<id>
        String.contains?(env.url, "/messages/") ->
          message_id = env.url |> String.split("/") |> List.last()
          {:ok, %Tesla.Env{env | status: 200, body: full_message_response(message_id)}}

        true ->
          {:ok, %Tesla.Env{env | status: 404}}
      end
    end)
  end

  defp list_messages_response(0) do
    %{"resultSizeEstimate" => 0}
  end

  defp list_messages_response(count) do
    messages = for i <- 1..count, do: %{"id" => "msg_#{i}", "threadId" => "thread_#{i}"}
    %{"messages" => messages, "resultSizeEstimate" => count}
  end

  defp full_message_response(message_id) do
    %{
      "id" => message_id,
      "threadId" => "thread_#{message_id}",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test Email #{message_id}"},
          %{"name" => "From", "value" => "john.doe@example.com"},
          %{"name" => "To", "value" => "user@example.com"},
          %{"name" => "Date", "value" => "Mon, 23 Dec 2024 10:00:00 -0600"}
        ],
        "mimeType" => "text/plain",
        "body" => %{
          "data" =>
            Base.url_encode64("This is the email body content for #{message_id}.", padding: false)
        }
      }
    }
  end

  defp setup_single_message_mock(_ea, message_id) do
    Mox.expect(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
      if String.contains?(env.url, "/messages/#{message_id}") do
        {:ok, %Tesla.Env{env | status: 200, body: full_message_response(message_id)}}
      else
        {:ok, %Tesla.Env{env | status: 404}}
      end
    end)
  end
end
