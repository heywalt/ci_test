defmodule MarketingWeb.PartnerController do
  use MarketingWeb, :controller

  plug :put_layout, html: :marketing

  def iree(conn, _params) do
    meta_tags = %{
      title: "Institute of Real Estate Education | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Institute of Real Estate Education | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :iree, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def realtyone(conn, _params) do
    meta_tags = %{
      title: "Realty ONE Group | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Realty ONE Group | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :realtyone, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def easy_street(conn, _params) do
    meta_tags = %{
      title: "Easy Street Offers | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Easy Street Offers | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :easy_street, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def nahrep(conn, _params) do
    meta_tags = %{
      title: "NAHREP | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "NAHREP | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :nahrep, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def utreschool(conn, _params) do
    meta_tags = %{
      title: "UT Real Estate School | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "UT Real Estate School| Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :utreschool, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def obeo(conn, _params) do
    meta_tags = %{
      title: "OBEO | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "OBEO | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :obeo, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def rocketlister(conn, _params) do
    meta_tags = %{
      title: "RocketLister | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "RocketLister | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :rocketlister, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def texas_realtors_assoc(conn, _params) do
    meta_tags = %{
      title: "Texas Realtors Association | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Texas Realtors Association | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :texas_realtors_assoc, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def showami(conn, _params) do
    meta_tags = %{
      title: "Showami | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Showami | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :showami, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def sisu(conn, _params) do
    meta_tags = %{
      title: "Sisu | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Sisu | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :sisu, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def skyslope(conn, _params) do
    meta_tags = %{
      title: "SkySlope | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "SkySlope | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :skyslope, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def sold(conn, _params) do
    meta_tags = %{
      title: "Sold.com | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Sold.com | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :sold, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  defp os(conn) do
    ua =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    ua.os.family
  end
end
