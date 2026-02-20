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

# ============================================================================
# Jarga App Configuration
# ============================================================================

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

# Configures the Entity Relationship Manager endpoint (Graph API)
config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: EntityRelationshipManager.Views.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub

# Configures the JargaApi endpoint (JSON API)
config :jarga_api, JargaApi.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: JargaApi.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub

# Configures the AgentsApi endpoint (JSON API for agent management)
config :agents_api, AgentsApi.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AgentsApi.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub

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

# Configures the mailer
config :jarga, Jarga.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  jarga: [
    args:
      ~w(js/app.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/jarga_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  identity: [
    args:
      ~w(js/app.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/identity/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  exo_dashboard: [
    args:
      ~w(js/app.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/exo_dashboard/assets", __DIR__),
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
  ],
  identity: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/identity", __DIR__)
  ],
  exo_dashboard: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/exo_dashboard", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# ============================================================================
# Identity App Configuration
# ============================================================================

config :identity,
  ecto_repos: [Identity.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Identity endpoint configuration
config :identity, IdentityWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IdentityWeb.ErrorHTML, json: IdentityWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub,
  live_view: [signing_salt: "identity_lv_salt"]

# ============================================================================
# ExoDashboard App Configuration
# ============================================================================

config :exo_dashboard, ExoDashboardWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExoDashboardWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Jarga.PubSub,
  live_view: [signing_salt: "exo_dashboard_salt"]

# Shared session configuration - must match jarga_web for session sharing
config :identity, :session_options,
  store: :cookie,
  key: "_jarga_key",
  signing_salt: "shared_session_salt",
  same_site: "Lax"

# Identity mailer configuration
config :identity, Identity.Mailer, adapter: Swoosh.Adapters.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
