import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/walt_ui start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :walt_ui, WaltUiWeb.Endpoint, server: true
  config :marketing, MarketingWeb.Endpoint, server: true
end

config :appsignal, :config,
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY", ""),
  revision: System.get_env("GIT_SHA", "")

config :walt_ui, :google,
  android_client_id: System.get_env("GOOGLE_ANDROID_CLIENT_ID"),
  ios_client_id: System.get_env("GOOGLE_IOS_CLIENT_ID"),
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  service_account_credentials_json: System.get_env("WALT_UI_SERVICE_ACCOUNT_JSON")

config :walt_ui, :google_maps, api_key: System.get_env("GOOGLE_API_KEY")

config :walt_ui, :google_custom_search,
  api_key: System.get_env("GOOGLE_API_KEY"),
  search_engine_id: System.get_env("GOOGLE_CUSTOM_SEARCH_ENGINE_ID")

config :walt_ui, :skyslope, client_id: System.get_env("SKYSLOPE_CLIENT_ID")

# Configures Ueberauth's Auth0 auth provider
config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: System.get_env("AUTH0_DOMAIN"),
  client_id: System.get_env("AUTH0_AUTH_CLIENT_ID"),
  client_secret: System.get_env("AUTH0_AUTH_CLIENT_SECRET")

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

config :prima_auth0_ex, :clients,
  default_client: [
    # Base url for Auth0 API
    auth0_base_url: System.get_env("AUTH0_URL"),
    # Credentials on Auth0
    client_id: System.get_env("AUTH0_API_CLIENT_ID"),
    client_secret: System.get_env("AUTH0_API_CLIENT_SECRET"),
    # Namespace for tokens of this client on the shared cache. Should be unique per client
    cache_namespace: "hey_walt"
  ]

if config_env() == :prod do
  database_host = System.get_env("DATABASE_HOST")
  database_port = String.to_integer(System.get_env("DATABASE_PORT") || "5432")

  repo_connection_opts =
    if database_host do
      [hostname: database_host, port: database_port]
    else
      [
        socket_dir: ~s|/tmp/cloudsql/#{System.get_env("DB_CONNECTION")}|,
        socket_options: []
      ]
    end

  house_canary_connection_opts =
    if database_host do
      [hostname: database_host, port: database_port]
    else
      [
        socket_dir: ~s|/tmp/cloudsql/#{System.get_env("HOUSE_CANARY_DB_CONNECTION")}|,
        socket_options: []
      ]
    end

  event_store_connection_opts =
    if database_host do
      [hostname: database_host, port: database_port]
    else
      [socket_dir: ~s|/tmp/cloudsql/#{System.get_env("DB_CONNECTION")}|]
    end

  config :repo, Repo, [
    {:database, "walt_ui"},
    {:password, System.get_env("DB_PASSWORD")},
    {:pool_size, String.to_integer(System.get_env("POOL_SIZE") || "200")},
    {:queue_target, 5_000},
    {:username, "postgres"}
    | repo_connection_opts
  ]

  config :repo, HouseCanaryRepo, [
    {:database, "house_canary"},
    {:password, System.get_env("HOUSE_CANARY_DB_PASSWORD")},
    {:pool_size, String.to_integer(System.get_env("HOUSE_CANARY_POOL_SIZE") || "5")},
    {:queue_target, 5_000},
    {:username, "postgres"}
    | house_canary_connection_opts
  ]

  config :cqrs, CQRS.EventStore, [
    {:database, "eventstore"},
    {:username, "postgres"},
    {:password, System.get_env("DB_PASSWORD")},
    {:queue_target, 5_000}
    | event_store_connection_opts
  ]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :walt_ui, WaltUiWeb.Endpoint,
    check_origin: ["//*.heywalt.ai"],
    url: [host: System.get_env("APP_HOST") || "app.heywalt.ai", port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: System.get_env("APP_PORT") || "8080",
      stream_handlers: [:cowboy_telemetry_h, WaltUiWeb.CowboyNoServerHeader, :cowboy_stream_h]
    ],
    secret_key_base: secret_key_base

  config :marketing, MarketingWeb.Endpoint,
    check_origin: ["//*.heywalt.ai"],
    url: [host: System.get_env("WWW_HOST") || "heywalt.ai", port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: System.get_env("WWW_PORT") || "8008",
      stream_handlers: [:cowboy_telemetry_h, MarketingWeb.CowboyNoServerHeader, :cowboy_stream_h]
    ],
    secret_key_base: secret_key_base

  # Running with this for now, though it would be nice to not have to interpolate
  # this in configs like this. Just make the whole URL the env var and set it straight up:
  # Like so:
  # config :walt_ui, WaltUi.Auth0, base_url: System.get_env("AUTH0_URL")
  config :walt_ui, WaltUi.Auth0, base_url: System.get_env("AUTH0_URL")

  config :walt_ui, WaltUi.Trestle, api_key: System.get_env("TRESTLE_API_KEY")

  config :walt_ui, WaltUi.Faraday,
    base_url: System.get_env("FARADAY_API_URL"),
    api_key: System.get_env("FARADAY_API_KEY")

  config :open_api_typesense,
    api_key: System.get_env("TYPESENSE_KEY"),
    host: System.get_env("TYPESENSE_HOST"),
    port: 443,
    scheme: "https"

  config :walt_ui, WaltUi.HumanLoop, api_key: System.get_env("HUMANLOOP_API_KEY")

  # This config is for the OpenAI library.
  config :openai,
    api_key: System.get_env("OPENAI_KEY"),
    organization_key: System.get_env("OPENAI_ORGANIZATION_KEY")

  config :stripity_stripe,
    api_key: System.get_env("STRIPE_API_KEY"),
    signing_secret: System.get_env("STRIPE_SIGNING_SECRET")

  config :walt_ui, :revenue_cat,
    base_url: "https://api.revenuecat.com/",
    public_api_key: System.get_env("REVENUE_CAT_STRIPE_PUBLIC_API_KEY"),
    auth_secret: System.get_env("REVENUE_CAT_AUTH_SECRET")

  config :libcluster,
    topologies: [
      walt_ui: [
        strategy: WaltUi.Google.Cluster.Strategy,
        config: [project: "heywalt"]
      ]
    ]

  config :walt_ui, WaltUi.Mailchimp, api_key: System.get_env("MAILCHIMP_API_KEY")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :walt_ui, WaltUiWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :walt_ui, WaltUiWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :walt_ui, WaltUi.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
