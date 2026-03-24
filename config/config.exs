# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :walt_ui,
  ecto_repos: [Repo, HouseCanaryRepo],
  generators: [context_app: :repo, binary_id: true]

config :repo, Repo, migration_primary_key: [type: :uuid]
config :repo, HouseCanaryRepo, migration_primary_key: [type: :uuid]

# Hammer rate limiting configuration
config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [
       # 1 minute expiry (matches our per-second rate limits)
       expiry_ms: 60_000,
       # Clean up expired entries every minute
       cleanup_interval_ms: 60_000
     ]}

config :cqrs, event_stores: [CQRS.EventStore]

config :cqrs, CQRS,
  registry: :global,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: CQRS.EventStore
  ]

config :cqrs, CQRS.EventStore,
  serializer: Commanded.Serialization.JsonSerializer,
  pool_size: 75

config :cqrs, CQRS,
  pubsub: [
    phoenix_pubsub: [
      adapter: Phoenix.PubSub.PG2,
      pool_size: 1
    ]
  ]

# Configures the app endpoint
config :walt_ui, WaltUiWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: WaltUiWeb.ErrorHTML, json: WaltUiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WaltUi.PubSub,
  live_view: [signing_salt: "3vJcsHA2"]

# Configures the marketing endpoint
config :marketing, MarketingWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: MarketingWeb.ErrorHTML, json: MarketingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Marketing.PubSub,
  live_view: [signing_salt: "QekrZuLi"]

# Email recipients are logged, but no email is sent.
#
# Production should be setup in config/runtime.exs to point at an actual
# email service (like Sendgrid).
config :walt_ui, WaltUi.Mailer, adapter: Swoosh.Adapters.Logger
config :swoosh, local: false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.0",
  app: [
    args: ~w(
        js/app.js
        --bundle
        --outdir=../priv/static/assets
        --external:/fonts/*
        --external:/images/*
      ),
    cd: Path.expand("../apps/walt_ui/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  marketing: [
    args: ~w(
        js/app.js
        --bundle
        --outdir=../priv/static/assets
        --external:/fonts/*
        --external:/images/*
        --define:POSTHOG_API_URL="https://us.i.posthog.com"
        --define:POSTHOG_API_KEY="#{System.get_env("POSTHOG_API_KEY")}"
        ),
    cd: Path.expand("../apps/marketing/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.0",
  app: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/walt_ui/assets", __DIR__)
  ],
  marketing: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/marketing/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time [$level] $message $metadata\n",
  metadata: [
    :action,
    :adaptive_sizing,
    :address_count,
    :admin,
    :admin_id,
    :args,
    :age_validation,
    :batches_enqueued,
    :calendar_events_count,
    :chunk,
    :chunk_size,
    :city,
    :contact_count,
    :contact_id,
    :contacts_scheduled,
    :count,
    :date_string,
    :details,
    :duplicates,
    :duration_ms,
    :email,
    :email_addresses,
    :email_addresses_count,
    :emails_count,
    :enrichment_id,
    :enrichment_type,
    :error,
    :error_code,
    :event_id,
    :exception,
    :event_type,
    :external_account_id,
    :failed_chunks,
    :failures,
    :fallback_used,
    :first_result,
    :file_id,
    :gpt_fallback_used,
    :has_page_token,
    :jaro_distance,
    :job,
    :job_id,
    :latitude,
    :longitude,
    :match_result,
    :match_type,
    :memory_mb,
    :message_id,
    :metadata,
    :min_provider_score,
    :module,
    :new,
    :new_events,
    :oban_job,
    :offset,
    :old,
    :operation,
    :owner_count,
    :phase,
    :pid,
    :phone,
    :previous_progress,
    :previous_status,
    :progress,
    :projection_status,
    :provider_scores,
    :provider_type,
    :ptt_score,
    :query,
    :query_length,
    :reason,
    :request_id,
    :result,
    :score,
    :selected_owner_score,
    :selection_score,
    :stacktrace,
    :state,
    :stats,
    :status,
    :stripe_customer_id,
    :stripe_event_id,
    :street_1,
    :successful_chunks,
    :sync_days,
    :sync_id,
    :sync_type,
    :task_id,
    :timestamp,
    :to_jitter,
    :total,
    :total_chunks,
    :total_contacts,
    :total_enrichments,
    :total_messages,
    :total_results,
    :total_so_far,
    :unified_contact_id,
    :updated_fields,
    :user_id,
    :value,
    :zip
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Register Server-Sent Events MIME type for streaming responses
config :mime, :types, %{
  "text/event-stream" => ["event-stream"]
}

# Configures Ueberauth
config :ueberauth, Ueberauth,
  providers: [
    auth0:
      {Ueberauth.Strategy.Auth0,
       [default_scope: "openid profile email https://www.googleapis.com/auth/contacts.readonly"]},
    google:
      {Ueberauth.Strategy.Google,
       [
         default_scope:
           "profile email https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/calendar.events.readonly https://www.googleapis.com/auth/calendar.readonly",
         access_type: "offline",
         prompt: "consent"
       ]}
  ]

config :walt_ui, WaltUi.Google.Calendars, base_url: "https://www.googleapis.com/calendar/v3"

config :walt_ui, WaltUi.Google.Gmail, base_url: "https://www.googleapis.com/gmail/v1"

config :walt_ui, WaltUi.HumanLoop, base_url: "https://api.humanloop.com/v5"

config :walt_ui, WaltUi.Mailchimp,
  base_url: "https://us17.api.mailchimp.com/3.0/",
  list_id: "76d094d43e"

config :walt_ui, WaltUi.Skyslope, base_url: "https://forms.skyslope.com/partner/api"

config :walt_ui, WaltUi.Trestle, base_url: "https://api.trestleiq.com"

# TODO: Don't have this yet, may need to add it at some point...
# client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# pub_cert = Path.join([Application.app_dir(:walt_ui, "priv"), "certs/auth0_public.key"]) |> File.read!()
# Will not allow a file to be read here
# pub_cert = Path.join([:code.priv_dir(:walt_ui), "certs", "auth0_public.key"]) |> File.read!()
config :joken,
  rs256: [
    signer_alg: "RS256",
    key_pem: """
    -----BEGIN CERTIFICATE-----
    MIIDHTCCAgWgAwIBAgIJYcp6ZY7wtW7eMA0GCSqGSIb3DQEBCwUAMCwxKjAoBgNV
    BAMTIWRldi12cTZodG1rcTF6eG0ybGZ2LnVzLmF1dGgwLmNvbTAeFw0yNDA1MTMx
    NTI5NThaFw0zODAxMjAxNTI5NThaMCwxKjAoBgNVBAMTIWRldi12cTZodG1rcTF6
    eG0ybGZ2LnVzLmF1dGgwLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
    ggEBAOH6n98/0RFop5iYaD2VoH9D3qD08DYXsKT/Uti913ws/DsLm+88c/cVKWcu
    5X17zqEEwRWLKLcYx6dahWNJB/hEH3PCvYUppsasLNFeJGPqAzEfLAaS7RjhWTtm
    CgdIgreWMylTN1kte4qvoGyK2jQmRihPVd4QXGoAc/7vcSyzN3po4AuRvcrnwSCa
    T+j2xPN0uj3ZYEjWvT7I6MMllblM+9alroH9sqQnEC4BUpRemF5DgN+8hEOEMVSX
    SdbW1VWVcgPvnIZBEe35jSQEgWI0mlXe2SXnBC7rEAyp+4Js6zib3gS6wc2SkrrC
    YxisVFxMAGSP9RnEn7Yx+tEfzakCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAd
    BgNVHQ4EFgQUwfxfWdU47bqEcL/B11ATELdt1ZgwDgYDVR0PAQH/BAQDAgKEMA0G
    CSqGSIb3DQEBCwUAA4IBAQAFN0BVvSRDFg8hbBlN/DVaYUWnpkoTOvr9sL+O/DR+
    JcrAmlbcNoJyiR/jCfGZKyQFjdaxzQu0Au2bRj2iNnLdNPBzz69UPba1lf3AVt/c
    ajh092HEGke2gRMqTEcfGJlvEi7SJzzkLH/ef8jjU1fF9fZFfn336P366PslIeIl
    h5Jo9e5paaMRxTeVodcvDKDhWeiIam8oMq3sTqOT3fraODLwJSjCeY1MSspExBgO
    /3vUvfTHIR2fJbdwMrM3irSAW0NSKvPOP7/nhBjD8BB6JSHNrlaenkDvNa4Zk+K+
    o666076oWjr73OFL3LjGhxFWIJmOKG4zc0MY2UoxcOjg
    -----END CERTIFICATE-----
    """
  ]

config :ex_aws,
  access_key_id: [{:system, "AMAZON_ACCESS_KEY"}, :instance_role],
  secret_access_key: [{:system, "AMAZON_SECRET_KEY"}, :instance_role]

config :posthog,
  api_url: "https://us.i.posthog.com",
  api_key: System.get_env("POSTHOG_API_KEY")

config :walt_ui, WaltUi.Contacts.CreateContactsConsumer, batch_size: 1_000

config :walt_ui, :ai_usage, monthly_token_limit: 1_000_000

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :appsignal, :config,
  active: false,
  ecto_repos: [Repo],
  enable_host_metrics: false,
  name: "WaltUI",
  otp_app: :walt_ui

config :walt_ui, :stripe,
  return_url: "https://app.heywalt.ai/dashboard",
  success_url: "https://heywalt.ai/checkout/success",
  cancel_url: "https://heywalt.ai/checkout/canceled"

config :walt_ui, Oban,
  engine: Oban.Pro.Engines.Smart,
  repo: Repo,
  queues: [
    default: 10,
    email_sync: 1,
    contact_email_sync: 2,
    contact_calendar_sync: 2,
    endato: 100,
    enrichment: 10,
    faraday: 100,
    geocoding: 50,
    historical_email_sync: 2,
    jitter: 1,
    jitter_search: 1,
    open_ai: [
      local_limit: 50,
      global_limit: [
        allowed: 1,
        burst: false,
        partition: [args: :contact_id]
      ]
    ],
    scripts: 10,
    showcase: 10,
    tasks: 10,
    trestle: [
      local_limit: 64,
      global_limit: [
        allowed: 1,
        burst: true,
        partition: [args: :user_id]
      ]
    ],
    unification: 1,
    user: 1
  ]

# Historical sync configuration
config :walt_ui, :historical_sync,
  contacts_chunk_size: 1000,
  max_contacts_in_memory: 5000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
