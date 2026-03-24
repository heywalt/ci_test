defmodule WaltUi.Authentication.AdminPlug do
  @moduledoc """
  Plug for verifying user token.
  """
  import Plug.Conn
  require Logger

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    current_user = Map.get(conn.assigns, :current_user)

    # dbg(conn.assigns)

    if current_user && current_user.is_admin do
      Logger.metadata(user_id: current_user.id)
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.put_view(WaltUiWeb.ErrorHTML)
      |> Phoenix.Controller.render(:unauthorized)
      |> halt()
    end
  end
end
