defmodule JargaApi.Endpoint do
  use Phoenix.Endpoint, otp_app: :jarga_api

  # Enable Ecto Sandbox for tests.
  # NOTE: Uses :jarga (not :jarga_api) because :jarga owns the Ecto repos
  # (Jarga.Repo) and the sandbox config. jarga_api has no repos of its own.
  if Application.compile_env(:jarga, :sandbox, false) do
    plug(Phoenix.Ecto.SQL.Sandbox)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(JargaApi.Router)
end
