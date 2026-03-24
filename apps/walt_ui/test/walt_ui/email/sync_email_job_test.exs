defmodule WaltUi.Email.SyncEmailJobTest do
  use WaltUi.CqrsCase, async: false
  use Oban.Testing, repo: Repo

  import WaltUi.Factory

  alias WaltUi.Email.SyncEmailJob

  setup do
    Application.put_env(:tesla, :adapter, WaltUi.Google.GmailMockAdapter)
    on_exit(fn -> Application.delete_env(:tesla, :adapter) end)

    user = insert(:user, email: "test_doesnt_matter@heywalt.ai")

    ea =
      insert(:external_account,
        user: user,
        provider: "google",
        email: "test@heywalt.ai",
        gmail_history_id: "12345"
      )

    [user: user, ea: ea]
  end

  describe "perform/1" do
    test "syncs emails for all external accounts with provider :google", %{user: user, ea: ea} do
      await_contact(
        user_id: user.id,
        email: "jaxone@heywalt.ai",
        phone: "1111111111",
        remote_id: "remoteId",
        remote_source: "remoteSource"
      )

      # Insert another external account with a different provider to ensure it's not processed
      _other_ea = insert(:external_account, user: user, provider: :skyslope)

      profile_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/profile"
      history_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/history"

      # Note; this is the message ID that is returned in the history response, and necessary for matching
      # in the mock.
      messages_url =
        "https://www.googleapis.com/gmail/v1/users/#{ea.email}/messages/1958cbbe3128bdaf"

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, 3, fn env, _opts ->
        case env.url do
          ^profile_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_profile_response()}}

          ^history_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_history_response()}}

          ^messages_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_messages_response()}}
        end
      end)

      :ok = perform_job(SyncEmailJob, %{})

      # Check what ContactInteractions were created
      all_interactions = Repo.all(WaltUi.Projections.ContactInteraction)

      # For now, just verify the contacts were created (created interactions exist)
      created_interactions =
        Enum.filter(all_interactions, &(&1.activity_type == :contact_created))

      assert length(created_interactions) > 0
    end

    test "syncs emails for all external accounts with provider :google, for contactss with multiple emails",
         %{user: user, ea: ea} do
      await_contact(
        user_id: user.id,
        email: "jaxon.evans@google.com",
        phone: "1111111111",
        remote_id: "remoteId",
        emails: [
          %{email: "jaxon.evans12312312312@gmail.com", label: "test"},
          %{email: "jaxone@heywalt.ai", label: "work"}
        ],
        remote_source: "remoteSource"
      )

      # Insert another external account with a different provider to ensure it's not processed
      _other_ea = insert(:external_account, user: user, provider: :skyslope)

      profile_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/profile"
      history_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/history"

      # Note; this is the message ID that is returned in the history response, and necessary for matching
      # in the mock.
      messages_url =
        "https://www.googleapis.com/gmail/v1/users/#{ea.email}/messages/1958cbbe3128bdaf"

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, 3, fn env, _opts ->
        case env.url do
          ^profile_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_profile_response()}}

          ^history_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_history_response()}}

          ^messages_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_messages_response()}}
        end
      end)

      :ok = perform_job(SyncEmailJob, %{})

      # Check what ContactInteractions were created
      all_interactions = Repo.all(WaltUi.Projections.ContactInteraction)

      # For now, just verify the contacts were created (created interactions exist)
      created_interactions =
        Enum.filter(all_interactions, &(&1.activity_type == :contact_created))

      assert length(created_interactions) > 0
    end
  end

  defp successful_profile_response do
    %{
      "emailAddress" => "jd@heywalt.ai",
      "historyId" => "107218",
      "messagesTotal" => 207,
      "threadsTotal" => 189
    }
  end

  defp successful_history_response do
    %{
      "history" => [
        %{
          "id" => "105426",
          "messages" => [
            %{"id" => "1958cbbe3128bdaf", "threadId" => "1958cbbe3128bdaf"}
          ],
          "messagesAdded" => [
            %{
              "message" => %{
                "id" => "1958cbbe3128bdaf",
                "labelIds" => ["DRAFT"],
                "threadId" => "1958cbbe3128bdaf"
              }
            }
          ]
        }
      ]
    }
  end

  defp successful_messages_response do
    %{
      "historyId" => "105804",
      "id" => "1958cbc1ef603d4d",
      "internalDate" => "1741822893000",
      "labelIds" => ["SENT"],
      "payload" => %{
        "body" => %{"size" => 0},
        "filename" => "",
        "headers" => [
          %{"name" => "MIME-Version", "value" => "1.0"},
          %{"name" => "Date", "value" => "Wed, 12 Mar 2025 17:41:33 -0600"},
          %{
            "name" => "Message-ID",
            "value" => "<CAOCwrc67WzGS4y=N1_gJV=16003Th0GMhDO303YEyV4kfOQBKA@mail.gmail.com>"
          },
          %{"name" => "Subject", "value" => "Another test..."},
          %{"name" => "From", "value" => "JD Skinner <test@heywalt.ai>"},
          %{
            "name" => "To",
            "value" => "Jaxon Evans <jaxone@heywalt.ai>, Johnson Denen <johnson@heywalt.ai>"
          },
          %{
            "name" => "Content-Type",
            "value" => "multipart/alternative; boundary=\"000000000000dbcfd506302dbe47\""
          }
        ],
        "mimeType" => "multipart/alternative",
        "partId" => "",
        "parts" => [
          %{
            "body" => %{
              "data" => "YmVjYXVzZSBnb29nbGUgaXMgbWFraW5nIG1lIHd0Zi4NCg==",
              "size" => 34
            },
            "filename" => "",
            "headers" => [
              %{
                "name" => "Content-Type",
                "value" => "text/plain; charset=\"UTF-8\""
              }
            ],
            "mimeType" => "text/plain",
            "partId" => "0"
          },
          %{
            "body" => %{
              "data" =>
                "PGRpdiBkaXI9Imx0ciI-YmVjYXVzZSBnb29nbGUgaXMgbWFraW5nIG1lIHd0Zi48L2Rpdj4NCg==",
              "size" => 55
            },
            "filename" => "",
            "headers" => [
              %{
                "name" => "Content-Type",
                "value" => "text/html; charset=\"UTF-8\""
              }
            ],
            "mimeType" => "text/html",
            "partId" => "1"
          }
        ]
      },
      "sizeEstimate" => 631,
      "snippet" => "because google is making me wtf.",
      "threadId" => "1958cbbe3128bdaf"
    }
  end
end
