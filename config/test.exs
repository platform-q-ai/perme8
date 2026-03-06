import Config

# Load .env.test for test environment overrides (mirrors dev.exs .env loading).
# Values act as defaults — pre-existing env vars (e.g. CI's DATABASE_URL) are
# NOT overwritten.
if File.exists?(".env.test") do
  File.read!(".env.test")
  |> String.split("\n")
  |> Enum.each(fn line ->
    line = String.trim(line)

    unless String.starts_with?(line, "#") or line == "" do
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          unless System.get_env(key) do
            value = String.trim(value)

            value =
              if String.starts_with?(value, "'") and String.ends_with?(value, "'") do
                String.slice(value, 1..-2//1)
              else
                value
              end

            System.put_env(key, value)
          end

        _ ->
          :ok
      end
    end
  end)
end

# Set environment to test
config :jarga, :env, :test

# Enable LiveDashboard route in test so we can verify basic auth behaviour
config :jarga, live_dashboard_in_prod: true

# Fast document save debouncing for tests (1ms)
config :jarga, :document_save_debounce_ms, 1

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
# DATABASE_URL is set by .env.test (loaded above), CI workflow env, or shell export.
# MIX_TEST_PARTITION is appended for parallel test partitions.
database_url =
  System.get_env("DATABASE_URL") ||
    raise "DATABASE_URL is not set. Ensure .env.test exists or export it in your shell."

database_url = database_url <> "#{System.get_env("MIX_TEST_PARTITION")}"

config :jarga, Jarga.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 15,
  # LiveView processes during exo-bdd browser tests hold connections for the
  # full scenario duration, easily exceeding the default 120s ownership timeout.
  ownership_timeout: :infinity

# Identity uses the same database as Jarga
config :identity, Identity.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 15,
  ownership_timeout: :infinity

# Agents uses the same database as Jarga
# pool_size 10: reduced from 15 to stay within Postgres max_connections.
# 6 repos total: Jarga(15)+Identity(15)+Agents(10)+Chat(10)+Notifications(15)+Webhooks(5) = 70 connections.
config :agents, Agents.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ownership_timeout: :infinity

# Chat uses the same database as Jarga
config :chat, Chat.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ownership_timeout: :infinity

# Notifications uses the same database as Jarga
# pool_size 15 required: jarga-web browser tests (exo-bdd) run concurrent
# scenarios that each load the notification bell component via LiveView,
# exhausting smaller pools under sandbox ownership semantics.
config :notifications, Notifications.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 15,
  ownership_timeout: :infinity

config :notifications, env: :test

# Identity URL for login redirects.
# Test ports use the 5xxx range (mirroring dev 4xxx) to avoid conflicts.
# AgentsWeb: dev 4014 → test 5014
config :agents_web, :identity_url, "http://localhost:5001"
# JargaWeb URL for cross-app back-links (e.g., workspace back navigation)
config :agents_web, :jarga_web_url, "http://localhost:5000"

config :agents_web, AgentsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5014],
  # Must match Identity's secret_key_base so the shared session cookie
  # (_identity_key) signed by Identity can be verified by agents_web.
  secret_key_base: "test_identity_secret_key_base_at_least_64_bytes_long_for_security"

# AgentsWeb URL for cross-app agent management links
config :jarga_web, :agents_web_url, "http://localhost:5014"

# JargaWeb: dev 4000 → test 5000
config :jarga_web, JargaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5000],
  secret_key_base: "k/DpMQ7vB/8OirPNBlAhucs6RCPp5ZRK09Is1Sd7Jb+YThz21IeYYYpueAbJYNEd"

# ERM: dev 4005 → test 5005
config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5005],
  secret_key_base: "erm_test_secret_key_base_at_least_64_bytes_long_for_security_purposes"

# ERM repository configuration.
# Unit tests (ExUnit) use Mox mocks by default.
# Integration/BDD tests set ERM_REAL_REPOS=true in the server env,
# which triggers the Application module to swap in real implementations
# at startup (SchemaRepository + InMemoryGraphRepository).
config :entity_relationship_manager,
  schema_repository: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
  graph_repository: EntityRelationshipManager.Mocks.GraphRepositoryMock

# Webhooks uses the same database as Jarga.
# pool_size kept small (5) to stay within Postgres max_connections.
# 6 repos total: Jarga(15)+Identity(15)+Agents(10)+Chat(10)+Notifications(15)+Webhooks(5) = 70 connections.
config :webhooks, Webhooks.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  ownership_timeout: :infinity

# WebhooksApi: dev 4016 → test 5016
config :webhooks_api, WebhooksApi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5016],
  secret_key_base: "webhooks_api_test_secret_key_base_at_least_64_bytes_long_for_security",
  server: true

config :webhooks, :env, :test

# JargaApi: dev 4004 → test 5004
config :jarga_api, JargaApi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5004],
  secret_key_base: "jarga_api_test_secret_key_base_at_least_64_bytes_long_for_security"

# AgentsApi: dev 4008 → test 5008
config :agents_api, AgentsApi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5008],
  secret_key_base: "agents_api_test_secret_key_base_at_least_64_bytes_long_for_security"

# ============================================================================
# Identity App Test Configuration
# ============================================================================

# Identity session signing salt (shared with agents_web for cookie portability)
# Kept separate from :session_options to avoid compile_env vs runtime mismatch in releases.
config :identity, :session_signing_salt, "test_identity_session_signing_salt"

# Identity: dev 4001 → test 5001
config :identity, IdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  secret_key_base: "test_identity_secret_key_base_at_least_64_bytes_long_for_security"

# ============================================================================
# ExoDashboard App Test Configuration
# ============================================================================

# ExoDashboard: dev 4010 → test 5010
config :exo_dashboard, ExoDashboardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5010],
  secret_key_base:
    "exo_dashboard_test_secret_key_base_that_is_at_least_64_bytes_long_for_security"

# ============================================================================
# Perme8Dashboard App Test Configuration
# ============================================================================

# Identity URL for login redirects
config :perme8_dashboard, :identity_url, "http://localhost:5001"

# Perme8Dashboard: dev 4012 → test 5012
config :perme8_dashboard, Perme8DashboardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5012],
  # Must match Identity's secret_key_base so the shared session cookie
  # (_identity_key) signed by Identity can be verified by perme8_dashboard.
  secret_key_base: "test_identity_secret_key_base_at_least_64_bytes_long_for_security"

# In test we don't send emails
config :identity, Identity.Mailer, adapter: Swoosh.Adapters.Test

# In test we don't send emails
config :jarga, Jarga.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Agents Sessions: faster health checks for tests
config :agents, :sessions,
  image: "perme8-opencode",
  health_check_interval_ms: 100,
  health_check_max_retries: 5,
  github_sync_enabled: false

# Agents MCP: Use streamable_http transport in tests with start: true
config :agents, :mcp_transport, {:streamable_http, start: true}

# Agents MCP HTTP: dev 4007 → test 5007
config :agents, :mcp_http, port: 5007

# Skip orphan recovery at boot — runs outside sandbox and conflicts with Mox
config :agents, :skip_orphan_recovery, true
