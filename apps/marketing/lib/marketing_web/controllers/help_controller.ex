defmodule MarketingWeb.HelpController do
  use MarketingWeb, :controller

  plug :put_layout, html: :marketing

  def delete_account(conn, _params) do
    meta_tags = %{
      title: "Permanently delete your account | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Permanently delete your account | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    render(conn, :delete_account, meta_tags: meta_tags, og_tags: og_tags)
  end
end
