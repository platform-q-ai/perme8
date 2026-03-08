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
# Perme8 Events Configuration
# ============================================================================

config :perme8_events, pubsub: Perme8.Events.PubSub

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
  pubsub_server: Perme8.Events.PubSub

# Configures the JargaApi endpoint (JSON API)
config :jarga_api, JargaApi.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: JargaApi.ErrorJSON],
    layout: false
  ],
  pubsub_server: Perme8.Events.PubSub

# Configures the WebhooksApi endpoint (JSON API for webhooks)
config :webhooks_api, WebhooksApi.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: WebhooksApi.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub

config :webhooks,
  ecto_repos: [Webhooks.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the AgentsApi endpoint (JSON API for agent management)
config :agents_api, AgentsApi.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AgentsApi.ErrorJSON],
    layout: false
  ],
  pubsub_server: Perme8.Events.PubSub

# Configures the AgentsWeb endpoint (Sessions UI)
config :agents_web, AgentsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AgentsWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Perme8.Events.PubSub,
  live_view: [signing_salt: "aG3ntSe5"]

# Configures the endpoint
config :jarga_web, JargaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JargaWeb.ErrorHTML, json: JargaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Perme8.Events.PubSub,
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
  ],
  perme8_dashboard: [
    args:
      ~w(js/app.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/perme8_dashboard/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  agents: [
    args:
      ~w(js/app.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/agents_web/assets", __DIR__),
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
  ],
  perme8_dashboard: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/perme8_dashboard", __DIR__)
  ],
  agents: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/agents_web", __DIR__)
  ]

# ============================================================================
# Chat App Configuration
# ============================================================================

config :chat,
  ecto_repos: [Chat.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# ============================================================================
# Agents App Configuration
# ============================================================================

config :agents,
  ecto_repos: [Agents.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# ============================================================================
# Notifications App Configuration
# ============================================================================

config :notifications,
  ecto_repos: [Notifications.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :agents, :sessions,
  image: "perme8-opencode",
  health_check_interval_ms: 2_000,
  health_check_max_retries: 180,
  github_sync_enabled: true,
  github_project_org: "platform-q-ai",
  github_project_number: 7,
  github_ticket_statuses: ["Backlog", "Ready"],
  github_poll_interval_ms: 15_000

# MCP tool providers: modules implementing ToolProvider behaviour
config :agents, :mcp_tool_providers, [
  Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider,
  Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider,
  Agents.Infrastructure.Mcp.ToolProviders.ToolsToolProvider
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
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  app_name: "Perme8",
  mailer_from_email: "noreply@perme8.app",
  mailer_from_name: "Perme8",
  signed_in_redirect_path: "/app",
  base_url: "http://localhost:4000"

# Identity endpoint configuration
config :identity, IdentityWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IdentityWeb.ErrorHTML, json: IdentityWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Perme8.Events.PubSub,
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
  pubsub_server: Perme8.Events.PubSub,
  live_view: [signing_salt: "exo_dashboard_salt"]

# ============================================================================
# Perme8Dashboard App Configuration
# ============================================================================

config :perme8_dashboard, Perme8DashboardWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Perme8DashboardWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Perme8.Events.PubSub,
  live_view: [signing_salt: "perme8_dashboard_salt"]

# Identity session configuration
# Apps that delegate auth to Identity (agents_web) must use the same key and salt.
#
# The signing_salt uses an MFA tuple so Plug.Session.Cookie resolves it at
# runtime via IdentityWeb.Session.signing_salt/0, which reads the value from
# Application.get_env(:identity, :session_signing_salt).  This avoids a
# compile_env vs runtime mismatch in releases — the MFA tuple itself is the
# same at both compile time and runtime; only its *return value* varies per
# environment.
#
# The actual salt is set per-environment:
#   dev.exs / test.exs  → hardcoded string
#   runtime.exs (prod)  → IDENTITY_SESSION_SIGNING_SALT env var
config :identity, :session_options,
  store: :cookie,
  key: "_identity_key",
  signing_salt: {IdentityWeb.Session, :signing_salt, []},
  same_site: "Lax"

# Identity mailer configuration
config :identity, Identity.Mailer, adapter: Swoosh.Adapters.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
