defmodule AgentsApi.Endpoint do
  use Phoenix.Endpoint, otp_app: :agents_api

  # Enable Ecto Sandbox for tests.
  # NOTE: Uses :identity (not :agents_api) because :identity owns the Ecto repos
  # and the sandbox config. agents_api has no repos of its own.
  if Application.compile_env(:identity, :sandbox, false) do
    plug(Phoenix.Ecto.SQL.Sandbox)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(AgentsApi.Router)
end
