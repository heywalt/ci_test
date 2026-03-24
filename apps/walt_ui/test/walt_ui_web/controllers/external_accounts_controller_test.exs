defmodule WaltUiWeb.Api.Controllers.ExternalAccountsControllerTest do
  use WaltUiWeb.ConnCase, async: false

  import WaltUi.Factory

  alias WaltUi.ExternalAccounts

  setup_all do
    Tesla.Mock.mock_global(fn
      # Gmail API profile endpoint
      %{method: :get, url: url} ->
        cond do
          String.contains?(url, "/gmail/v1/users/") and String.contains?(url, "/profile") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "emailAddress" => "test@example.com",
                "historyId" => "12345",
                "messagesTotal" => 100,
                "threadsTotal" => 50
              }
            }

          String.contains?(url, "/gmail/v1/users/") and String.contains?(url, "/history") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "history" => [
                  %{
                    "id" => "12346",
                    "messagesAdded" => [
                      %{
                        "message" => %{
                          "id" => "msg1",
                          "threadId" => "thread1"
                        }
                      }
                    ]
                  }
                ]
              }
            }

          String.contains?(url, "/gmail/v1/users/") and String.contains?(url, "/messages/") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "id" => "msg1",
                "threadId" => "thread1",
                "payload" => %{
                  "headers" => [
                    %{"name" => "Subject", "value" => "Test Subject"},
                    %{"name" => "From", "value" => "sender@example.com"},
                    %{"name" => "To", "value" => "recipient@example.com"},
                    %{"name" => "Date", "value" => "Wed, 12 Mar 2025 17:41:33 -0600"}
                  ]
                }
              }
            }

          true ->
            %Tesla.Env{status: 404, body: "Not Found"}
        end
    end)

    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/external-accounts" do
    setup do
      [
        user:
          insert(:user, email: "test_external_accounts_#{System.unique_integer()}@example.com")
      ]
    end

    test "creates and returns the created external account", %{user: %{id: user_id}} = ctx do
      expires_in = DateTime.utc_now() |> DateTime.add(1, :hour) |> DateTime.to_unix()

      payload = %{
        "provider" => "google",
        "access_token" => "ACCESS_TOKEN",
        "refresh_token" => "REFRESH_TOKEN",
        "expires_in" => expires_in,
        "token_source" => "ios"
      }

      assert %{
               "data" => %{
                 "attributes" => %{"id" => _, "provider" => "google", "user_id" => ^user_id}
               }
             } =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> post(~p"/api/external-accounts", payload)
               |> json_response(200)
    end

    test "updates and returns the updated external account if one already exists",
         %{user: %{id: user_id}} = ctx do
      insert(:external_account, user: ctx.user, provider: "google", token_source: "ios")

      expires_in = DateTime.utc_now() |> DateTime.add(1, :hour) |> DateTime.to_unix()

      payload = %{
        "provider" => "google",
        "access_token" => "ACCESS_TOKEN",
        "refresh_token" => "REFRESH_TOKEN",
        "expires_in" => expires_in,
        "token_source" => "ios"
      }

      assert %{
               "data" => %{
                 "attributes" => %{"id" => _, "provider" => "google", "user_id" => ^user_id}
               }
             } =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> post(~p"/api/external-accounts", payload)
               |> json_response(200)
    end
  end

  describe "DELETE /api/external-accounts/:id" do
    setup do
      [user: insert(:user)]
    end

    test "deletes the external account", %{user: %{id: user_id}} = ctx do
      expires_in = DateTime.utc_now() |> DateTime.add(1, :hour) |> DateTime.to_unix()

      payload = %{
        "provider" => "google",
        "access_token" => "ACCESS_TOKEN",
        "refresh_token" => "REFRESH_TOKEN",
        "expires_in" => expires_in,
        "token_source" => "ios",
        "user_id" => user_id
      }

      assert {:ok, ea} = ExternalAccounts.create_from_mobile(payload)

      assert ctx.conn
             |> authenticate_user(ctx.user)
             |> delete(~p"/api/external-accounts/#{ea}")
             |> response(204)
    end
  end
end
