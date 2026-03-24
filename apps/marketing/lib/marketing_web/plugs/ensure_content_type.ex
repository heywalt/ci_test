defmodule MarketingWeb.Plug.EnsureContentType do
  @moduledoc """
  Ensures all HTTP responses have a Content-Type header set.

  This plug addresses security scanner findings where responses (especially redirects)
  might be missing the Content-Type header. While browsers typically handle this
  gracefully, RFC 7231 recommends all responses include Content-Type.

  The plug sets a default Content-Type of "text/html; charset=utf-8" if none is present.

  Usage:
    plug MarketingWeb.Plug.EnsureContentType
  """

  import Plug.Conn

  @behaviour Plug

  @default_content_type "text/html; charset=utf-8"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    register_before_send(conn, &ensure_content_type/1)
  end

  defp ensure_content_type(conn) do
    case get_resp_header(conn, "content-type") do
      [] ->
        put_resp_header(conn, "content-type", @default_content_type)

      [""] ->
        put_resp_header(conn, "content-type", @default_content_type)

      _has_content_type ->
        conn
    end
  end
end
