import Config

# Document save debouncing (2 seconds)
config :jarga, :document_save_debounce_ms, 2000

# Load .env file for development
if File.exists?(".env") do
  File.read!(".env")
  |> String.split("\n")
  |> Enum.each(fn line ->
    line = String.trim(line)

    unless String.starts_with?(line, "#") or line == "" do
      case String.split(line, "=", parts: 2) do
        [key, value] ->
          # Remove quotes if present
          value = String.trim(value)

          value =
            if String.starts_with?(value, "'") and String.ends_with?(value, "'") do
              String.slice(value, 1..-2//1)
            else
              value
            end

          System.put_env(key, value)

        _ ->
          :ok
      end
    end
  end)
end

# Configure your database
database_url =
  System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost/jarga_dev"

config :jarga, Jarga.Repo,
  url: database_url,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Identity uses the same database as Jarga
config :identity, Identity.Repo,
  url: database_url,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Entity Relationship Manager dev configuration (Graph API on port 4005)
config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4005],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "erm_dev_secret_key_base_at_least_64_bytes_long_for_security_purposes",
  watchers: []

# JargaApi dev configuration (JSON API on port 4004)
config :jarga_api, JargaApi.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4004],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "jarga_api_dev_secret_key_base_at_least_64_bytes_long_for_security",
  watchers: []

# For development, we disable any cache and enable
# debugging and code reloading.
config :jarga_web, JargaWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "z2bXp51SEtZFL32o7/fqNVjKmCk4md8HcgslBm35L4dV0Izs8D+HqKw6nLeuBQVd",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:jarga, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:jarga, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :jarga_web, JargaWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/jarga_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :jarga_web, dev_routes: true

# ============================================================================
# Identity App Development Configuration
# ============================================================================

config :identity, IdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_identity_secret_key_base_at_least_64_bytes_long_for_security",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:identity, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:identity, ~w(--watch)]}
  ]

config :identity, IdentityWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/identity_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for identity dashboard and mailbox
config :identity, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# ============================================================================
# Agents App Development Configuration
# ============================================================================

# Agents MCP: Enable StreamableHTTP transport in dev
config :agents, :mcp_transport, {:streamable_http, start: true}

# Agents MCP HTTP: Standalone Bandit server for MCP endpoint on port 4007
config :agents, :mcp_http, port: 4007

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
