defmodule MarketingWeb.Plug.SecurityHeaders do
  @moduledoc """
  Removes or modifies HTTP response headers that could leak server
  technology and version information to potential attackers.

  This plug helps prevent server fingerprinting and security issues by:
  - Removing the 'X-Powered-By' header (if present)
  - Adding 'X-Content-Type-Options: nosniff' to prevent MIME-sniffing attacks
  - Adding 'Strict-Transport-Security' (HSTS) header in production to enforce HTTPS

  Note: The 'Server' header is removed via a Cowboy stream handler
  (see MarketingWeb.CowboyNoServerHeader) since it's added at the HTTP adapter level.

  Usage:
    plug MarketingWeb.Plug.SecurityHeaders
  """

  import Plug.Conn

  @behaviour Plug

  @secure_cookies Application.compile_env(:marketing, :secure_cookies, false)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    register_before_send(conn, &apply_security_headers/1)
  end

  defp apply_security_headers(conn) do
    conn
    |> delete_resp_header("x-powered-by")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_hsts_header()
  end

  defp put_hsts_header(conn) do
    # Only set HSTS in production (HTTPS)
    # max-age=31536000 = 1 year
    # includeSubDomains = apply to all subdomains
    if @secure_cookies do
      put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")
    else
      conn
    end
  end
end
