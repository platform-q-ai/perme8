defmodule AgentsApi.OpenApiControllerTest do
  use AgentsApi.ConnCase

  describe "GET /api/openapi" do
    test "returns OpenAPI specification as JSON", %{conn: conn} do
      response =
        conn
        |> get("/api/openapi")
        |> json_response(200)

      assert response["openapi"] == "3.0.3"
      assert response["info"]["title"] == "Agents API"
      assert is_map(response["paths"])
      assert Map.has_key?(response["paths"], "/api/agents")
      assert Map.has_key?(response["paths"], "/api/agents/{id}")
      assert Map.has_key?(response["paths"], "/api/agents/{id}/query")
      assert Map.has_key?(response["paths"], "/api/agents/{id}/skills")
    end

    test "does not require authentication", %{conn: conn} do
      conn
      |> get("/api/openapi")
      |> json_response(200)
    end
  end
end
