import Config

# Configure your database
config :repo, Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "walt_ui_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :repo, HouseCanaryRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "house_canary_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 5

config :cqrs, CQRS.EventStore,
  database: "eventstore_dev",
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
app_port = String.to_integer(System.get_env("PORT") || "4000")

config :walt_ui, WaltUiWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [
    ip: {127, 0, 0, 1},
    port: app_port,
    stream_handlers: [:cowboy_telemetry_h, WaltUiWeb.CowboyNoServerHeader, :cowboy_stream_h]
  ],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "oU2IaG4m7m2VempmnLL+VonOdnNdrUE65e1YoUkRyzObZFi7eZaft3x07JQ5AFkH",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:app, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:app, ~w(--watch)]}
  ]

marketing_port = String.to_integer(System.get_env("MARKETING_PORT") || "4001")

config :marketing, MarketingWeb.Endpoint,
  http: [
    ip: {127, 0, 0, 1},
    port: marketing_port,
    stream_handlers: [:cowboy_telemetry_h, MarketingWeb.CowboyNoServerHeader, :cowboy_stream_h]
  ],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "oCsg2YjOPk1N6TOKPo1adpEOealndB2ruwx52EjCqNeRxe4k3lAm2KzILik1x+Fj",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:marketing, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:marketing, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :walt_ui, WaltUiWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/walt_ui_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :marketing, MarketingWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/marketing_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :walt_ui, WaltUi.Auth0, base_url: System.get_env("AUTH0_URL")

config :walt_ui, WaltUi.Endato,
  base_url: System.get_env("ENDATO_URL"),
  api_id: System.get_env("ENDATO_API_ID"),
  api_key: System.get_env("ENDATO_API_KEY"),
  client: WaltUi.Enrichment.Endato.Dummy

config :walt_ui, WaltUi.Faraday,
  base_url: System.get_env("FARADAY_API_URL"),
  api_key: System.get_env("FARADAY_API_KEY"),
  client: WaltUi.Enrichment.Faraday.Dummy

config :walt_ui, WaltUi.Trestle,
  api_key: System.get_env("TRESTLE_API_KEY"),
  client: WaltUi.Enrichment.Trestle.Dummy

config :open_api_typesense,
  api_key: "localdevapikey",
  host: "localhost",
  port: 8108,
  scheme: "http"

config :walt_ui, WaltUi.HumanLoop, api_key: System.get_env("HUMANLOOP_API_KEY")

config :walt_ui, WaltUi.PubSub, client: WaltUi.PubSub.Aws

config :ex_aws, :sqs,
  create_contacts_url: System.get_env("SQS_CREATE_CONTACTS_URL"),
  upsert_contacts_url: System.get_env("SQS_UPSERT_CONTACTS_URL"),
  scheme: "http://",
  host: "localhost.localstack.cloud",
  # host with port is used in dev, specifically, unsure how to avoid the need for this
  host_with_port: "localhost.localstack.cloud:4566",
  port: 4566

config :walt_ui, WaltUi.Contacts.CreateContactsConsumer,
  batch_size: 10,
  producer: BroadwaySQS.Producer,
  producer_options: [
    queue_url: System.get_env("SQS_CREATE_CONTACTS_URL"),
    config: [
      wait_time_seconds: 20,
      batch_size: 10,
      receive_interval: 100,
      visibility_timeout: 30
    ]
  ]

config :walt_ui, WaltUi.Contacts.UpsertContactsConsumer,
  producer: BroadwaySQS.Producer,
  producer_options: [
    queue_url: System.get_env("SQS_UPSERT_CONTACTS_URL"),
    config: [
      wait_time_seconds: 20,
      batch_size: 10,
      receive_interval: 100,
      visibility_timeout: 30
    ]
  ],
  batcher_options: [
    batch_size: 10
  ]

# This config is for the OpenAI library.
config :openai,
  api_key: System.get_env("OPENAI_KEY"),
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY")

# This config is for our internal OpenAi env vars.
config :walt_ui, :open_ai, client: WaltUi.Enrichment.OpenAi.Dummy

config :stripity_stripe,
  api_key: System.get_env("STRIPE_DEV_API_KEY"),
  signing_secret: System.get_env("STRIPE_DEV_SIGNING_SECRET")

config :walt_ui, :stripe,
  return_url: "http://localhost:4000/dashboard",
  success_url: "http://localhost:4000/checkout/success",
  cancel_url: "http://localhost:4000/checkout/canceled"

config :walt_ui, :revenue_cat,
  base_url: "https://api.revenuecat.com/",
  public_api_key: System.get_env("REVENUE_CAT_STRIPE_PUBLIC_API_KEY"),
  auth_secret: System.get_env("REVENUE_CAT_AUTH_SECRET")

config :walt_ui, :skyslope, redirect_uri: "http://localhost:4000/auth/skyslope/callback"

# optional, use when required by an OpenAI API beta, e.g.:
# beta: "assistants=v1",
# optional, passed to [HTTPoison.Request](https://hexdocs.pm/httpoison/HTTPoison.Request.html) options
# http_options: [recv_timeout: 30_000],
# optional, useful if you want to do local integration tests using Bypass or similar
# (https://github.com/PSPDFKit-labs/bypass), do not use it for production code,
# but only in your test config!
# api_url: "http://localhost/"

# Enable dev routes for dashboard and mailbox
config :walt_ui, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n", level: :info

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

config :jsonapi,
  scheme: "http",
  namespace: "/api",
  field_transformation: :underscore,
  page: :page

# Disable libcluster in dev - not needed for local development
# To test multi-node locally, manually connect nodes with Node.connect/1
# config :libcluster, topologies: [walt_ui: [strategy: Cluster.Strategy.LocalEpmd]]
config :libcluster, topologies: []

config :marketing, :www, redirect_to: "http://localhost:4001"

config :walt_ui, WaltUi.Mailchimp, api_key: System.get_env("MAILCHIMP_API_KEY")

config :walt_ui, WaltUi.Enrichment.Gravatar, client: WaltUi.Enrichment.Gravatar.Dummy
