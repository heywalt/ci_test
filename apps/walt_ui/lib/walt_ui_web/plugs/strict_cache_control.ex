defmodule WaltUiWeb.Plug.StrictCacheControl do
  @moduledoc """
  Sets strict cache control headers to prevent caching of sensitive authenticated content.

  This plug prevents sensitive user data from being stored in shared caches (like proxy
  servers) that could leak information to other users.

  Sets the following headers:
  - Cache-Control: no-cache, no-store, must-revalidate, private
  - Pragma: no-cache (for HTTP 1.0 compatibility)
  - Expires: 0 (for HTTP 1.0 compatibility)

  This should be applied to authenticated routes where responses contain user-specific
  or sensitive data.

  Usage:
    pipeline :api_authenticated do
      plug WaltUi.Authentication.Plug
      plug WaltUiWeb.Plug.StrictCacheControl
    end
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    register_before_send(conn, &set_strict_cache_headers/1)
  end

  defp set_strict_cache_headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate, private")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
  end
end
