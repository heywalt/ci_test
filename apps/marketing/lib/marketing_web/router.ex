defmodule MarketingWeb.Router do
  use MarketingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MarketingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :robots do
    plug Plug.Static, at: "/", from: :marketing, gzip: false, only: ["robots.txt"]
  end

  scope "/", MarketingWeb, host: "www." do
    get "/*path", PageController, :www_redirect
  end

  scope "/", MarketingWeb do
    pipe_through [:robots, :browser]

    get "/", PageController, :index
    get "/contact", PageController, :contact
    get "/download", PageController, :download
    get "/privacy", PageController, :privacy
    get "/sitemap.xml", SitemapController, :index
    get "/terms", PageController, :terms

    # partners
    get "/iree", PartnerController, :iree
    get "/realtyonegroup", PartnerController, :realtyone
    get "/easy-street", PartnerController, :easy_street
    get "/nahrep", PartnerController, :nahrep
    get "/obeo", PartnerController, :obeo
    get "/rocketlister", PartnerController, :rocketlister
    get "/sisu", PartnerController, :sisu
    get "/showami", PartnerController, :showami
    get "/skyslope", PartnerController, :skyslope
    get "/sold.com", PartnerController, :sold
    get "/texas-realtors-assoc", PartnerController, :texas_realtors_assoc
    get "/utreschool", PartnerController, :utreschool

    scope "/.well-known" do
      get "/apple-app-site-association", WellKnownController, :aasa
      get "/assetlinks.json", WellKnownController, :assetlinks
    end

    scope "/blog" do
      get "/prioritize-top-5-database-without-burning-out",
          BlogController,
          :prioritize_top_5_database_without_burning_out
    end

    scope "/help" do
      get "/delete-account", HelpController, :delete_account
    end

    # pokémon route (must be last!)
    get "/*path", PageController, :catch_all
  end
end
