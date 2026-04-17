# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :core,
  ecto_repos: [Core.Repo]

config :api,
  ecto_repos: [Core.Repo],
  generators: [context_app: :core]

config :api,
  access_token: "news_hV7mQ2zN8pL4xR1kT9cY6sD3wF5bJ0"

config :core, :integrations,
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379"),
  rabbitmq_url: System.get_env("RABBITMQ_URL", "amqp://news:news@localhost:5672"),
  elasticsearch_url: System.get_env("ELASTICSEARCH_URL", "http://localhost:9200")

config :core, :article_render_queue_publisher_module, Core.ContentRenderer.QueuePublisher

config :core, Core.ContentRenderer.QueueConsumer,
  enabled: true,
  queue: "news.article_markdown.render",
  reconnect_ms: 5_000

config :core, Core.RateLimiter,
  enabled: true,
  redis_name: Core.RateLimiter.Redis,
  key_prefix: "api_rate_limit",
  limit: 35,
  window_seconds: 60

config :api,
  rate_limiter_enabled: true,
  rate_limiter_backend: Core.RateLimiter

config :articles_generator,
  enabled: true,
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379"),
  tick_interval_ms: 30_000,
  next_generation_key: "articles_generator:next_generation_at"

# Configures the endpoint
config :api, ApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ApiWeb.ErrorHTML, json: ApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Api.PubSub,
  live_view: [signing_salt: "m7sjNGzv"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  api: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/api/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  api: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/api", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

import_config "elastic_documents.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
