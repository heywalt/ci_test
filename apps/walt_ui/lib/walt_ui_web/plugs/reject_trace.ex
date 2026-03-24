defmodule WaltUiWeb.Plug.RejectTrace do
  @moduledoc """
  Rejects HTTP TRACE and TRACK methods to prevent Cross-Site Tracing (XST) attacks.

  TRACE and TRACK methods can be exploited to bypass HTTPOnly cookie protections
  and other security measures. This plug returns a 405 Method Not Allowed response
  for these methods while allowing all other standard HTTP methods including OPTIONS
  (which is required for CORS).

  Usage:
    plug WaltUiWeb.Plug.RejectTrace
  """

  import Plug.Conn

  @behaviour Plug

  @blocked_methods ["TRACE", "TRACK"]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: method} = conn, _opts) when method in @blocked_methods do
    conn
    |> send_resp(405, "Method Not Allowed")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
