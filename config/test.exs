import Config

# Set environment to test
config :jarga, :env, :test

# Enable LiveDashboard route in test so we can verify basic auth behaviour
config :jarga, live_dashboard_in_prod: true

# Fast document save debouncing for tests (1ms)
config :jarga, :document_save_debounce_ms, 1

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
database_url =
  System.get_env("DATABASE_URL") ||
    "postgres://postgres:postgres@localhost:5433/jarga_test#{System.get_env("MIX_TEST_PARTITION")}"

config :jarga, Jarga.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20,
  # LiveView processes during exo-bdd browser tests hold connections for the
  # full scenario duration, easily exceeding the default 120s ownership timeout.
  ownership_timeout: :infinity

# Identity uses the same database as Jarga
config :identity, Identity.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20,
  ownership_timeout: :infinity

config :jarga_web, JargaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "k/DpMQ7vB/8OirPNBlAhucs6RCPp5ZRK09Is1Sd7Jb+YThz21IeYYYpueAbJYNEd"

config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4006],
  secret_key_base: "erm_test_secret_key_base_at_least_64_bytes_long_for_security_purposes"

# ERM repository configuration.
# Unit tests (ExUnit) use Mox mocks by default.
# Integration/BDD tests set ERM_REAL_REPOS=true in the server env,
# which triggers the Application module to swap in real implementations
# at startup (SchemaRepository + InMemoryGraphRepository).
config :entity_relationship_manager,
  schema_repository: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
  graph_repository: EntityRelationshipManager.Mocks.GraphRepositoryMock

config :jarga_api, JargaApi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4005],
  secret_key_base: "jarga_api_test_secret_key_base_at_least_64_bytes_long_for_security"

# ============================================================================
# Identity App Test Configuration
# ============================================================================

config :identity, IdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
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

# Agents MCP: Use streamable_http transport in tests with start: true
config :agents, :mcp_transport, {:streamable_http, start: true}

# Agents MCP HTTP: Standalone Bandit server for MCP endpoint (exo-bdd tests)
config :agents, :mcp_http, port: 4007
