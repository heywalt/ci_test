defmodule WaltUiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :walt_ui

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_walt_ui_key",
    signing_salt: "QyOVa70+",
    same_site: "Lax",
    secure: Application.compile_env(:walt_ui, :secure_cookies, false)
  ]

  plug WaltUiWeb.Plug.HealthCheck
  plug WaltUiWeb.Plug.SecurityHeaders
  plug WaltUiWeb.Plug.RejectTrace
  plug WaltUiWeb.Plug.EnsureContentType

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :walt_ui,
    gzip: false,
    only: WaltUiWeb.static_paths(),
    cache_control_for_etags: "public, max-age=31536000, immutable"

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :walt_ui
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Stripe.WebhookPlug,
    at: "/webhooks/stripe",
    handler: WaltUiWeb.StripeHandler,
    secret: {Application, :get_env, [:stripity_stripe, :signing_secret]}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug WaltUiWeb.Router
end
