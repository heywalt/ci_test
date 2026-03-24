defmodule MarketingWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :marketing

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_marketing_key",
    signing_salt: "4LTD6OMY",
    same_site: "Lax",
    secure: Application.compile_env(:marketing, :secure_cookies, false)
  ]

  plug MarketingWeb.Plug.HealthCheck
  plug MarketingWeb.Plug.SecurityHeaders
  plug MarketingWeb.Plug.RejectTrace
  plug MarketingWeb.Plug.EnsureContentType

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :marketing,
    gzip: false,
    only: MarketingWeb.static_paths(),
    cache_control_for_etags: "public, max-age=31536000, immutable"

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MarketingWeb.Router
end
