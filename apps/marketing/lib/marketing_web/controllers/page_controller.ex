defmodule MarketingWeb.PageController do
  use MarketingWeb, :controller

  plug :put_layout, html: :marketing

  def contact(conn, _params) do
    meta_tags = %{
      title: "Contact | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Contact | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    # temporary
    render(conn, :contact, meta_tags: meta_tags, og_tags: og_tags)
  end

  def download(conn, _params) do
    meta_tags = %{
      title: "Download | Amby",
      description: ""
    }

    og_tags = %{
      "og:title": "Download | Amby",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    render(conn, :download, meta_tags: meta_tags, og_tags: og_tags)
  end

  def index(conn, _params) do
    meta_tags = %{
      title: "Turn your contacts into closings | Amby",
      description:
        "Discover the ready-to-move clients hiding in your network. Amby empowers real estate professionals to build stronger relationships."
    }

    og_tags = %{
      "og:title": "Turn your contacts into closings | Amby",
      "og:description":
        "Discover the ready-to-move clients hiding in your network. Amby empowers real estate professionals to build stronger relationships.",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    os = os(conn)

    render(conn, :index, meta_tags: meta_tags, og_tags: og_tags, os: os)
  end

  def pricing(conn, _params) do
    _meta_tags = %{
      title: "",
      description: ""
    }

    _og_tags = %{
      "og:title": "",
      "og:description": "",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    # temporary
    redirect(conn, to: "/")
  end

  def privacy(conn, _params) do
    meta_tags = %{
      title: "Privacy Policy | Amby",
      description:
        "Learn about Amby's privacy policies, data protection measures, and your privacy rights."
    }

    og_tags = %{
      "og:title": "Privacy Policy | Amby",
      "og:description":
        "Learn about Amby's privacy policies, data protection measures, and your privacy rights.",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    render(conn, :privacy, meta_tags: meta_tags, og_tags: og_tags)
  end

  def terms(conn, _params) do
    meta_tags = %{
      title: "Terms & Conditions | Amby",
      description: "Legal terms and conditions governing the use of Amby's services and platform."
    }

    og_tags = %{
      "og:title": "Terms & Conditions | Amby",
      "og:description":
        "Legal terms and conditions governing the use of Amby's services and platform.",
      "og:image": ~p"/images/og/default.png",
      "og:url": current_url(conn)
    }

    render(conn, :terms, meta_tags: meta_tags, og_tags: og_tags)
  end

  def catch_all(conn, _params) do
    redirect(conn, to: "/")
  end

  @redirect Application.compile_env(:marketing, [:www, :redirect_to], "https://heywalt.ai")

  def www_redirect(conn, _params) do
    redirect_to = "#{@redirect}#{conn.request_path}"

    conn
    |> put_status(:moved_permanently)
    |> redirect(external: redirect_to)
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
