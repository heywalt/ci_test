defmodule WaltUi.RevenueCat.WebhookPlug do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  require Logger

  @impl true
  def init(config), do: config

  @impl true
  def call(%{request_path: "/webhooks/revenue-cat"} = conn, _) do
    auth_secret = Application.get_env(:walt_ui, :revenue_cat)[:auth_secret]

    case Plug.Conn.get_req_header(conn, "authorization") do
      [token] when token == auth_secret ->
        conn

      _ ->
        Logger.warning("Failed to verify RevenueCat webhook.")

        conn
        |> send_resp(:bad_request, "Invalid Authorization")
        |> halt()
    end
  end

  def call(conn, _), do: conn
end
