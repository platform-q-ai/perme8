import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/cms start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :jarga_web, JargaWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Jarga Runtime Config
  jarga_host = System.get_env("JARGA_HOST") || System.get_env("PHX_HOST") || "localhost"
  jarga_port = String.to_integer(System.get_env("JARGA_PORT") || System.get_env("PORT") || "4000")

  config :jarga, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :jarga, Jarga.Repo,
    ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Build list of allowed origins for WebSocket connections
  check_origins = [
    "https://www.jarga.ai",
    "//www.jarga.ai",
    "https://jarga.ai",
    "//jarga.ai"
  ]

  check_origins =
    if jarga_host in ["www.jarga.ai", "jarga.ai"] do
      check_origins
    else
      check_origins ++ ["https://#{jarga_host}", "//#{jarga_host}"]
    end

  config :jarga_web, JargaWeb.Endpoint,
    url: [host: jarga_host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: jarga_port
    ],
    secret_key_base: secret_key_base,
    check_origin: check_origins

  # Mailer Config
  sendgrid_api_key = System.get_env("SENDGRID_API_KEY")

  if sendgrid_api_key do
    config :jarga, Jarga.Mailer,
      adapter: Swoosh.Adapters.Sendgrid,
      api_key: sendgrid_api_key
  end
end

# Load .env file in development and test environments
if config_env() in [:dev, :test] do
  env_files =
    if config_env() == :test do
      [".env", ".env.test", System.get_env()]
    else
      [".env", System.get_env()]
    end

  Dotenvy.source!(env_files)
end

# Configure OpenRouter for LLM chat
config :jarga, :openrouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  base_url: System.get_env("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
  chat_model: System.get_env("CHAT_MODEL", "google/gemini-2.5-flash-lite"),
  site_url: System.get_env("OPENROUTER_SITE_URL", "https://jarga.app"),
  app_name: System.get_env("OPENROUTER_APP_NAME", "Jarga")
