defmodule WaltUiWeb.ExternalAccountAuthController do
  use WaltUiWeb, :controller

  plug Ueberauth

  require Logger

  alias Ueberauth.Strategy.Helpers
  alias WaltUi.Account
  alias WaltUi.ExternalAccounts

  @providers ["google", "oauth", "skyslope"]

  def request(conn, %{"provider" => provider}) when provider in @providers do
    render(conn, "request.html", callback_url: Helpers.callback_url(conn))
  end

  def request(conn, %{"provider" => provider}) do
    conn
    |> put_flash(:error, "Failed to authenticate with #{inspect(provider)}.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, %{"provider" => provider}) do
    conn
    |> put_flash(:error, "Failed to authenticate with #{inspect(provider)}.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: nil}} = conn, %{"provider" => provider}) do
    conn
    |> put_flash(:error, "Failed to authenticate with #{inspect(provider)}.")
    |> redirect(to: "/contacts")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => provider}) do
    # Get the session_id from the Phoenix session
    session_id = get_session(conn, :session_id)

    # Look up the database session to get the authenticated user
    case session_id && Account.get_session(session_id) do
      {:ok, session} ->
        # User is authenticated - create external account for them
        case ExternalAccounts.create_from_web(session.user, auth, provider) do
          {:ok, _} ->
            conn
            |> put_flash(
              :info,
              "You've Successfully Logged in to your #{inspect(provider)} Account"
            )
            |> redirect(to: "/contacts")

          {:error, changeset} ->
            Logger.error("Error creating or updating external account: #{inspect(changeset)}")

            conn
            |> put_flash(:error, "There was an error authenticating with #{inspect(provider)}.")
            |> redirect(to: "/contacts")
        end

      _ ->
        # No valid session - user needs to log in first
        conn
        |> put_flash(:error, "Please log in first before connecting your Google account.")
        |> redirect(to: "/")
    end
  end
end
