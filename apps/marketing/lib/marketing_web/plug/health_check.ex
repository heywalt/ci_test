defmodule MarketingWeb.Plug.HealthCheck do
  @moduledoc """
  Plug for `/health-check` route. Halts before the request can continue, so it will not be logged.
  """
  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/health-check"} = conn, _opts) do
    conn
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
