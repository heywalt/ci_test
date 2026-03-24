defmodule WaltUiWeb.AuthController do
  use WaltUiWeb, :controller

  alias WaltUi.Account
  alias WaltUiWeb.Models.UserFromAuth

  plug Ueberauth

  def request(conn, %{"provider_name" => provider_name} = _params) do
    provider_config =
      case provider_name do
        "github" ->
          {Ueberauth.Strategy.Github,
           [
             default_scope: "user",
             request_path: "",
             callback_path: ""
           ]}
      end

    conn
    |> Ueberauth.run_request(provider_name, provider_config)
  end

  def login(conn, _params) do
    meta_tags = %{
      title: "",
      description: ""
    }

    og_tags = %{
      "og:title": "",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    current_user = nil

    conn
    |> put_layout(html: false)
    |> render(:login, meta_tags: meta_tags, og_tags: og_tags, current_user: current_user)
  end

  def logout(conn, _params) do
    auth0_config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)
    domain = auth0_config[:domain]
    client_id = auth0_config[:client_id]
    return_to = WaltUiWeb.Endpoint.url()

    logout_url =
      "https://#{domain}/v2/logout?client_id=#{client_id}&returnTo=#{URI.encode(return_to)}"

    conn
    |> configure_session(drop: true)
    |> redirect(external: logout_url)
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/login")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    # This is the only way I know how to get an id token for api testing
    # dbg(auth)

    conn = delete_resp_cookie(conn, "_walt_ui_key")

    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        # Create a session and store only the session ID in the cookie
        case Account.create_session(user, auth) do
          {:ok, session} ->
            return_to = get_session(conn, :return_to) || "/agenda"

            conn
            |> put_flash(:info, "Successfully authenticated.")
            |> put_session(:session_id, session.id)
            |> delete_session(:return_to)
            |> redirect(to: return_to)

          {:error, _changeset} ->
            conn
            |> put_flash(:error, "Failed to create session")
            |> redirect(to: "/login")
        end

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: "/login")
    end
  end
end
