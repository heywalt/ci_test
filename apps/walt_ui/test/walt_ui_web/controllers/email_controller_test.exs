defmodule WaltUiWeb.Api.Controllers.EmailControllerTest do
  use WaltUiWeb.ConnCase
  use Mimic

  import WaltUi.Factory

  alias WaltUi.Google.Gmail

  setup :verify_on_exit!

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "POST /api/email" do
    setup do
      [user: insert(:user, email: "user@heywalt.ai")]
    end

    test "sends an email and returns 204 NO CONTENT", %{user: user} = ctx do
      _ea = insert(:external_account, user: user, provider: :google)

      payload = %{
        to: "recipient@example.com",
        subject: "Test email from controller test",
        body: "<p>This is a test email with <strong>HTML</strong> content.</p>",
        provider: "google"
      }

      expect(Gmail, :send_email, fn _, _ -> {:ok, %{"id" => "message_id_123"}} end)

      assert ctx.conn
             |> authenticate_user(user)
             |> post(~p"/api/email", payload)
             |> response(204)
    end

    test "returns 400 Bad Request if missing required field", %{user: user} = ctx do
      _ea = insert(:external_account, user: user, provider: :google)

      # Missing 'body'
      payload = %{
        to: "recipient@example.com",
        subject: "Test email with missing body",
        provider: "google"
      }

      reject(Gmail, :send_email, 2)

      assert ctx.conn
             |> authenticate_user(user)
             |> post(~p"/api/email", payload)
             |> json_response(400)
    end

    test "returns 422 Unprocessable Entity if email address format is invalid",
         %{user: user} = ctx do
      _ea = insert(:external_account, user: user, provider: :google)

      payload = %{
        to: "not-a-valid-email",
        subject: "Test email with invalid recipient",
        body: "This email should not be sent.",
        provider: "google"
      }

      expect(Gmail, :send_email, fn _, _ -> {:error, %{"error" => "invalid_recipient"}} end)

      assert ctx.conn
             |> authenticate_user(user)
             |> post(~p"/api/email", payload)
             |> json_response(422)
    end

    test "returns 404 Not Found if user has no Google external account", %{user: user} = ctx do
      payload = %{
        to: "recipient@example.com",
        subject: "Test email",
        body: "This email should not be sent because there's no Google account.",
        provider: "google"
      }

      # Explicitly expecting 0 calls to send_email

      reject(Gmail, :send_email, 2)

      assert ctx.conn
             |> authenticate_user(user)
             |> post(~p"/api/email", payload)
             |> json_response(404)
    end
  end
end
