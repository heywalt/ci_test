defmodule WaltUiWeb.Api.AppleController do
  use WaltUiWeb, :controller

  require Logger

  action_fallback WaltUiWeb.FallbackController

  def create(conn, params) do
    Logger.info("Apple Notification, Create:")
    Logger.info(params)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:no_content, "")
  end

  def index(conn, params) do
    Logger.info("Apple Notification, Index:")
    Logger.info(params)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:no_content, "")
  end
end
