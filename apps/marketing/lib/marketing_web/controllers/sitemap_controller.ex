defmodule MarketingWeb.SitemapController do
  use MarketingWeb, :controller

  def index(conn, _params) do
    sitemap = Marketing.Sitemap.generate()

    conn
    |> put_resp_header("content-type", "application/xml")
    |> send_resp(200, sitemap)
  end
end
