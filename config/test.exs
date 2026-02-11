import Config

# Set environment to test
config :jarga, :env, :test

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
  pool_size: 20

# Identity uses the same database as Jarga
config :identity, Identity.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20

# Start server for Wallaby E2E tests
config :jarga_web, JargaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "k/DpMQ7vB/8OirPNBlAhucs6RCPp5ZRK09Is1Sd7Jb+YThz21IeYYYpueAbJYNEd",
  server: true

# ============================================================================
# Identity App Test Configuration
# ============================================================================

config :identity, IdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "test_identity_secret_key_base_at_least_64_bytes_long_for_security",
  server: true

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

# Configure Wallaby for E2E browser tests
config :wallaby,
  driver: Wallaby.Chrome,
  otp_app: :jarga_web,
  screenshot_on_failure: true,
  screenshot_dir: "tmp/screenshots",
  max_wait_time: 10_000,
  chromedriver: [
    headless: System.get_env("WALLABY_HEADED") != "true",
    capabilities: %{
      chromeOptions: %{
        args: [
          "--no-sandbox",
          "--disable-dev-shm-usage",
          "--disable-gpu",
          "--window-size=1920,1080",
          "--disable-extensions",
          "--disable-setuid-sandbox",
          "--disable-software-rasterizer",
          "--disable-background-timer-throttling",
          "--disable-backgrounding-occluded-windows",
          "--disable-renderer-backgrounding"
        ]
      }
    }
  ]

# Enable Ecto Sandbox for Wallaby tests
config :jarga, :sandbox, Ecto.Adapters.SQL.Sandbox

# Use mock LLM client for tests
config :jarga, :llm_client, Jarga.Test.Support.MockLlmClient

# Configure Cucumber for BDD feature testing
config :jarga_web, :cucumber,
  features: [
    "apps/jarga_web/test/features/**/*.feature"
  ],
  steps: ["apps/jarga_web/test/features/step_definitions/**/*.exs"]
