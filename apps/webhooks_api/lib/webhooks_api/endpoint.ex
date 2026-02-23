defmodule WebhooksApi.Endpoint do
  use Phoenix.Endpoint, otp_app: :webhooks_api

  # Enable Ecto Sandbox for tests.
  # NOTE: Uses :jarga (not :webhooks_api) because :jarga owns the shared
  # PubSub and sandbox config. webhooks_api.Repo shares the same database.
  if Application.compile_env(:jarga, :sandbox, false) do
    plug(Phoenix.Ecto.SQL.Sandbox)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    body_reader: {WebhooksApi.Plugs.CacheRawBody, :read_body, []}
  )

  plug(WebhooksApi.Router)
end
