# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :jarga, :scopes,
  user: [
    default: true,
    module: Jarga.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :user_id],
    schema_key: :user_id,
    schema_type: :string,
    schema_table: :users,
    test_data_fixture: Jarga.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :jarga,
  ecto_repos: [Jarga.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Chat context configuration
config :jarga, :chat_context,
  max_content_chars: 3000,
  max_messages_history: 20

config :cms,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :jarga_web, JargaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JargaWeb.ErrorHTML, json: JargaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub,
  live_view: [signing_salt: "5rdQlpgP"]

config :cms, CmsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CmsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Cms.PubSub,
  live_view: [signing_salt: "/PrEF0KO"]

# Configures the mailer
config :jarga, Jarga.Mailer, adapter: Swoosh.Adapters.Local
config :cms, Cms.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  jarga: [
    args:
      ~w(js/app.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/jarga_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  jarga: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/jarga_web", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :default_handler,
#       level: :info
#
#     config :logger, :default_formatter,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
