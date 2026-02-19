defmodule AgentsApi.OpenApiController do
  @moduledoc """
  Controller for serving the OpenAPI specification.
  """

  use AgentsApi, :controller

  # Read the OpenAPI spec at compile time — it's a static file that only changes at deploy.
  @external_resource Path.join([__DIR__, "..", "..", "..", "priv", "static", "openapi.json"])
  @spec_json File.read!(Path.join([__DIR__, "..", "..", "..", "priv", "static", "openapi.json"]))

  @doc """
  Returns the OpenAPI 3.0 specification as JSON.
  """
  def show(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, @spec_json)
  end
end
