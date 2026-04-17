import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :core, Core.Repo,
  username: System.get_env("POSTGRES_USER", "news_elixir"),
  password: System.get_env("POSTGRES_PASSWORD", "news_elixir"),
  hostname: System.get_env("POSTGRES_HOST", "elixir_db"),
  database:
    "#{System.get_env("POSTGRES_DB_TEST", "news_elixir_test")}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :api, ApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ojE/PcVrnqrEX4zWSfkq/ypqgltZ2TAWmteM7Imfqi7knu6pdPL4vSZIRIyp9Pgf",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Disable async search indexing side-effects in test environment.
# Integration/unit tests can override this per test when asserting events.
config :core, :search_events_module, Core.Search.NoopEvents
