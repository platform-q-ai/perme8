defmodule EntityRelationshipManager.Endpoint do
  use Phoenix.Endpoint, otp_app: :entity_relationship_manager

  # Enable Ecto Sandbox for tests.
  # NOTE: Uses :jarga (not :entity_relationship_manager) because :jarga owns
  # the Ecto repos (Jarga.Repo) and the sandbox config.
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

  plug(EntityRelationshipManager.Router)
end
