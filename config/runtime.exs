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
#     PHX_SERVER=true bin/identity start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :identity, IdentityWeb.Endpoint, server: true
end

# Identity uses a different port (default 4001) to avoid conflicts with jarga_web.
# Test uses the 5xxx range to avoid collisions with dev servers.
identity_default_port = if config_env() == :test, do: "5001", else: "4001"

config :identity, IdentityWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("IDENTITY_PORT") || identity_default_port)]

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # Identity session signing salt — shared with apps that delegate auth to Identity.
  # Stored under a separate key (not :session_options) to avoid compile_env vs
  # runtime mismatch in releases. Each endpoint merges it at boot.
  identity_session_signing_salt =
    System.get_env("IDENTITY_SESSION_SIGNING_SALT") ||
      raise """
      environment variable IDENTITY_SESSION_SIGNING_SALT is missing.
      You can generate one by calling: mix phx.gen.secret 32
      """

  config :identity, :session_signing_salt, identity_session_signing_salt

  # AgentsWeb shares Identity's session cookie, so it must use the same
  # secret_key_base to verify the cookie signature.
  agents_web_host = System.get_env("AGENTS_WEB_HOST") || host
  agents_web_port = String.to_integer(System.get_env("AGENTS_WEB_PORT") || "4014")

  config :agents_web, :identity_url, System.get_env("IDENTITY_URL") || "https://#{host}"
  config :agents_web, :jarga_web_url, System.get_env("JARGA_WEB_URL") || "https://#{host}"

  config :agents_web, AgentsWeb.Endpoint,
    url: [host: agents_web_host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: agents_web_port
    ],
    secret_key_base: secret_key_base

  config :identity, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Identity app config — base_url is used by notifiers to build email links
  identity_host = System.get_env("IDENTITY_HOST") || host

  config :identity,
    base_url: "https://#{identity_host}",
    app_name: System.get_env("IDENTITY_APP_NAME") || "Perme8",
    mailer_from_email: System.get_env("IDENTITY_MAILER_FROM_EMAIL") || "noreply@perme8.app",
    mailer_from_name: System.get_env("IDENTITY_MAILER_FROM_NAME") || "Perme8"

  config :identity, IdentityWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :identity, IdentityWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :identity, IdentityWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :identity, Identity.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

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
  config :jarga_api, JargaApi.Endpoint, server: true
  config :entity_relationship_manager, EntityRelationshipManager.Endpoint, server: true
  config :agents_web, AgentsWeb.Endpoint, server: true
  config :webhooks_api, WebhooksApi.Endpoint, server: true
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

  # Identity uses the same database as Jarga
  config :identity, Identity.Repo,
    ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Agents uses the same database as Jarga
  config :agents, Agents.Repo,
    ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Chat uses the same database as Jarga
  config :chat, Chat.Repo,
    ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # Notifications uses the same database as Jarga
  config :notifications, Notifications.Repo,
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

  # AgentsWeb URL for cross-app agent management links
  # Default to agents.#{jarga_host} subdomain — avoids self-referencing links
  # when AGENTS_WEB_URL / AGENTS_WEB_HOST are not explicitly set.
  config :jarga_web,
         :agents_web_url,
         System.get_env("AGENTS_WEB_URL") ||
           "https://#{System.get_env("AGENTS_WEB_HOST") || "agents.#{jarga_host}"}"

  config :jarga_web, JargaWeb.Endpoint,
    url: [host: jarga_host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: jarga_port
    ],
    secret_key_base: secret_key_base,
    check_origin: check_origins

  # JargaApi (JSON API) - separate port/host for independent scaling
  jarga_api_host = System.get_env("JARGA_API_HOST") || jarga_host

  jarga_api_port =
    String.to_integer(System.get_env("JARGA_API_PORT") || "4004")

  config :jarga_api, JargaApi.Endpoint,
    url: [host: jarga_api_host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: jarga_api_port
    ],
    secret_key_base: secret_key_base

  # Entity Relationship Manager (Graph API) - separate port/host
  erm_host = System.get_env("ERM_HOST") || jarga_host

  erm_port =
    String.to_integer(System.get_env("ERM_PORT") || "4005")

  config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
    url: [host: erm_host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: erm_port
    ],
    secret_key_base: secret_key_base

  # LiveDashboard Basic Auth credentials
  config :jarga,
    dashboard_username: System.get_env("DASHBOARD_USERNAME"),
    dashboard_password: System.get_env("DASHBOARD_PASSWORD")

  # Mailer Config
  sendgrid_api_key = System.get_env("SENDGRID_API_KEY")

  if sendgrid_api_key do
    config :jarga, Jarga.Mailer,
      adapter: Swoosh.Adapters.Sendgrid,
      api_key: sendgrid_api_key
  end
end

# ERM real repos flag — set by exo-bdd integration tests via ERM_REAL_REPOS=true
if System.get_env("ERM_REAL_REPOS") == "true" do
  config :entity_relationship_manager, :real_repos, true
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

# Sessions: pass secrets to ephemeral opencode Docker containers.
# In dev, derive secrets from local files if env vars aren't explicitly set.
github_app_pem =
  System.get_env("GITHUB_APP_PEM") ||
    case File.read(Path.expand("~/.config/perme8/private-key.pem")) do
      {:ok, pem} -> Base.encode64(pem)
      _ -> nil
    end

# OPENCODE_AUTH is read lazily at container start time (not boot time) so that
# re-authenticated tokens are picked up without requiring a Phoenix restart.
# See SessionsConfig.container_env/0 for the dynamic reader.
opencode_auth_source =
  System.get_env("OPENCODE_AUTH") ||
    {:file, Path.expand("~/.local/share/opencode/auth.json")}

config :agents, :sessions_env, %{
  GITHUB_APP_PEM: github_app_pem,
  OPENCODE_AUTH: opencode_auth_source,
  REPO_BRANCH: System.get_env("REPO_BRANCH")
}

default_sessions_image =
  if config_env() == :prod,
    do: "ghcr.io/platform-q-ai/perme8-opencode:latest",
    else: "perme8-opencode"

config :agents, :sessions,
  github_token: System.get_env("GH_TOKEN"),
  image: System.get_env("AGENTS_SESSIONS_IMAGE", default_sessions_image)

github_webhook_automation_enabled =
  System.get_env("GITHUB_WEBHOOK_AUTOMATION_ENABLED") in ["1", "true", "TRUE"]

config :agents, :github_webhook,
  enabled: github_webhook_automation_enabled,
  secret: System.get_env("GITHUB_WEBHOOK_SECRET"),
  automation_user_id: System.get_env("GITHUB_WEBHOOK_AUTOMATION_USER_ID"),
  repo: System.get_env("GITHUB_WEBHOOK_REPO", "platform-q-ai/perme8"),
  image: System.get_env("GITHUB_WEBHOOK_IMAGE", System.get_env("AGENTS_SESSIONS_IMAGE")),
  bot_identity: "perme8[bot]"

# Configure OpenRouter for LLM chat (consumed by Agents.Infrastructure.Services.LlmClient)
config :agents, :openrouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  base_url: System.get_env("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
  chat_model: System.get_env("CHAT_MODEL", "google/gemini-2.5-flash-lite"),
  site_url: System.get_env("OPENROUTER_SITE_URL", "https://jarga.app"),
  app_name: System.get_env("OPENROUTER_APP_NAME", "Jarga")
