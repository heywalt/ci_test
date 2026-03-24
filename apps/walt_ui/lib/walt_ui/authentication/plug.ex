defmodule WaltUi.Authentication.Plug do
  @moduledoc """
  Plug for verifying user token.
  """
  import Plug.Conn
  require Logger

  alias WaltUi.Account
  alias WaltUi.Authentication.Auth0

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    if user = Map.get(conn.assigns, :current_user) do
      Logger.metadata(user_id: user.id)

      assign(conn, :current_user, Repo.re_preload(user, [:external_accounts]))
    else
      conn
      |> maybe_auth_via_session()
      |> auth_via_token()
    end
  end

  # First we try to auth via the session, if one exists for the session_id in the cookie.
  # If that all goes well, the auth_via_token function will essentially be a no-op, since
  # it checks for the current_user that gets placed in the session here. Otherwise, re-auth
  # will continue via Auth0.
  defp maybe_auth_via_session(conn) do
    if String.starts_with?(conn.request_path, "/api/") do
      # Skip session auth for API routes
      conn
    else
      auth_via_session(conn)
    end
  end

  defp auth_via_session(conn) do
    case get_session(conn, :session_id) do
      nil ->
        conn

      session_id ->
        case Account.get_session(session_id) do
          {:ok, session} ->
            user = Repo.re_preload(session.user, [:external_accounts])
            Logger.metadata(user_id: user.id)
            assign(conn, :current_user, user)

          {:error, reason} ->
            Logger.error("Error getting session: #{inspect(reason)}")

            conn
            |> delete_session(:session_id)
        end
    end
  end

  defp auth_via_token(conn) do
    if Map.get(conn.assigns, :current_user) do
      conn
    else
      with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
           {:ok, false} <- {:ok, Auth0.jwt_expired?(token)},
           {:ok, attrs} <- Auth0.user_attrs_from_mobile_token(token),
           {:ok, user} <- Account.find_or_create_user_by_oauth_user(attrs) do
        Logger.metadata(user_id: user.id)
        assign(conn, :current_user, user)
      else
        _error ->
          conn
          |> put_status(:unauthorized)
          |> Phoenix.Controller.put_view(WaltUiWeb.ErrorJSON)
          |> Phoenix.Controller.render(:unauthorized)
          |> halt()
      end
    end
  end
end
