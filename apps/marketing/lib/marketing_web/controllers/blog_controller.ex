defmodule MarketingWeb.BlogController do
  use MarketingWeb, :controller

  plug :put_layout, html: :marketing

  def prioritize_top_5_database_without_burning_out(conn, _params) do
    meta_tags = %{
      title: "How to prioritize the top 5% of your database without burning out | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "How to prioritize the top 5% of your database without burning out | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    render(conn, :prioritize_top_5_database_without_burning_out,
      meta_tags: meta_tags,
      og_tags: og_tags
    )
  end
end
