import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :repo, Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "walt_ui_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

config :repo, HouseCanaryRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "house_canary_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox

config :cqrs, CQRS,
  event_store: [
    adapter: Commanded.EventStore.Adapters.InMemory,
    event_store: CQRS.EventStore
  ]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :walt_ui, WaltUiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "cckLypBc22NWAVnrnfvvEoaiPslx82/cLmDAPlqQDT0yunMNELTzpDBUdN8e4dlv",
  server: false

config :marketing, MarketingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "0PLuCo/hFhY/0Vxte0wLLUA97JAeQxHpKdt03LRjEQ7zDr5xspoSOYfTOXFTwq6H",
  server: false

# In test we don't send emails.
config :walt_ui, WaltUi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable calendar sync in tests
config :walt_ui, :calendar_sync_enabled, false

# Disable external account caching in tests to avoid interference with mocks
config :walt_ui, :enable_external_account_caching, false

config :walt_ui, goth_enabled?: false

config :walt_ui, WaltUi.Contacts.CreateContactsConsumer,
  context: %{bulk_create_fun: fn msgs -> length(msgs) end},
  producer: Broadway.DummyProducer,
  queue_url: "create-contacts-url"

config :walt_ui, WaltUi.Contacts.UpsertContactsConsumer,
  producer: Broadway.DummyProducer,
  queue_url: "upsert-contacts-url"

config :walt_ui, WaltUi.UnifiedRecords.Contact.UnificationFsm,
  enrichment_timeout: 500,
  max_retries: 1,
  retry_interval_ms: 10,
  await_timeout: 100

config :stripity_stripe,
  api_key: "sk_test_thisisaboguskey",
  api_base_url: "http://localhost:12111"

config :walt_ui, :stripe,
  success_url: "http://localhost:4000/checkout/success",
  cancel_url: "http://localhost:4000/checkout/canceled"

config :walt_ui, Oban, testing: :inline

config :libcluster, topologies: [walt_ui_test: [strategy: WaltUi.StubCluster]]

# Disable leader election in tests - start CQRS directly
config :walt_ui, :cqrs_leader_enabled, false

config :walt_ui, WaltUi.Handlers.Search, enabled?: false
config :walt_ui, WaltUi.Handlers.Unification, enabled?: false
config :walt_ui, WaltUi.Handlers.EmailSyncOnLeadCreated, enabled?: false
config :walt_ui, WaltUi.Handlers.EmailSyncOnContactUpdate, enabled?: false
config :walt_ui, WaltUi.Handlers.CalendarSyncOnLeadCreated, enabled?: false
config :walt_ui, WaltUi.Handlers.CalendarSyncOnContactUpdate, enabled?: false
config :walt_ui, WaltUi.Handlers.GeocodeOnAddressChange, enabled?: false

# Disable process managers in tests to avoid event noise
config :walt_ui, WaltUi.ProcessManagers.ContactEnrichmentManager, enabled?: false
config :walt_ui, WaltUi.ProcessManagers.EnrichmentOrchestrationManager, enabled?: false
config :walt_ui, WaltUi.ProcessManagers.CalendarMeetingsManager, enabled?: false
config :walt_ui, WaltUi.ProcessManagers.EnrichmentResetManager, enabled?: false
config :walt_ui, WaltUi.ProcessManagers.UnificationManager, enabled?: false

config :tesla, adapter: Tesla.Mock

config :walt_ui, WaltUi.Enrichment.Gravatar, client: WaltUi.Enrichment.Gravatar.Dummy

config :walt_ui, WaltUi.Endato,
  base_url: "http://localhost:12345",
  api_id: "test_api_id",
  api_key: "test_api_key",
  client: WaltUi.Enrichment.Endato.Dummy

config :walt_ui, WaltUi.Faraday,
  base_url: "http://localhost:12346",
  api_key: "test_api_key",
  client: WaltUi.Enrichment.Faraday.Dummy

config :walt_ui, WaltUi.Trestle, client: WaltUi.Enrichment.Trestle.Dummy

config :walt_ui, WaltUi.ProcessManagers.UnificationManager, openai_retry_sleep_ms: 10
