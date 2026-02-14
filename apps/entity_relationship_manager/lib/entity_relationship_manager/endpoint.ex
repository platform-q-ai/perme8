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

  plug(:parse_body)
  plug(EntityRelationshipManager.Router)

  defp parse_body(conn, _opts) do
    Plug.Parsers.call(
      conn,
      Plug.Parsers.init(
        parsers: [:urlencoded, :multipart, :json],
        json_decoder: Phoenix.json_library()
      )
    )
  rescue
    Plug.Parsers.ParseError ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        400,
        Jason.encode!(%{error: "bad_request", message: "Invalid JSON in request body"})
      )
      |> halt()

    Plug.Parsers.UnsupportedMediaTypeError ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        415,
        Jason.encode!(%{
          error: "unsupported_content_type",
          message: "Content-Type must be application/json"
        })
      )
      |> halt()
  end
end
