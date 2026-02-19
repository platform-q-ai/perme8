defmodule AgentsApi.OpenApiController do
  @moduledoc """
  Controller for serving the OpenAPI specification.
  """

  use AgentsApi, :controller

  @doc """
  Returns the OpenAPI 3.0 specification as JSON.
  """
  def show(conn, _params) do
    spec_path = Application.app_dir(:agents_api, "priv/static/openapi.json")

    case File.read(spec_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, content)

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "OpenAPI specification not found"})
    end
  end
end
