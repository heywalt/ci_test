defmodule WaltUi.Authentication.WebPlug do
  @moduledoc """
  Plug for web-based authentication that redirects to login.
  """
  import Plug.Conn
  import Phoenix.Controller
  require Logger

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case get_session(conn, :session_id) do
      nil ->
        redirect_to_login(conn)

      session_id ->
        case WaltUi.Account.get_session(session_id) do
          {:ok, session} ->
            user = Repo.re_preload(session.user, [:external_accounts])
            Logger.metadata(user_id: user.id)
            assign(conn, :current_user, user)

          {:error, _reason} ->
            conn
            |> delete_session(:session_id)
            |> redirect_to_login()
        end
    end
  end

  defp redirect_to_login(conn) do
    conn
    |> put_flash(:error, "Please log in to continue")
    |> redirect(to: "/login")
    |> halt()
  end
end
