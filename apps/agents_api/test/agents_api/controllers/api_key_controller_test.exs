defmodule AgentsApi.ApiKeyControllerTest do
  use AgentsApi.ConnCase

  alias AgentsApi.Test.Fixtures

  setup %{conn: conn} do
    user = Fixtures.user_fixture()
    {_api_key, token} = Fixtures.api_key_fixture(user.id)

    authed_conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, user: user, authed_conn: authed_conn}
  end

  describe "POST /api/api-keys" do
    test "creates API key with explicit permissions", %{authed_conn: conn} do
      params = %{
        "name" => "Scoped Key",
        "description" => "Read-only key",
        "permissions" => ["agents:read", "agents:query"]
      }

      response =
        conn
        |> post("/api/api-keys", params)
        |> json_response(201)

      assert %{"data" => data} = response
      assert data["name"] == "Scoped Key"
      assert data["permissions"] == ["agents:read", "agents:query"]
      assert data["id"] != nil
      assert response["token"] != nil
    end

    test "creates API key with nil permissions when omitted", %{authed_conn: conn} do
      response =
        conn
        |> post("/api/api-keys", %{"name" => "Legacy Compatible Key"})
        |> json_response(201)

      assert %{"data" => data} = response
      assert data["permissions"] == nil
    end
  end

  describe "PATCH /api/api-keys/:id" do
    test "updates API key permissions", %{authed_conn: conn, user: user} do
      {api_key, _token} = Fixtures.api_key_fixture(user.id, %{permissions: ["agents:read"]})

      response =
        conn
        |> patch("/api/api-keys/#{api_key.id}", %{"permissions" => ["agents:write"]})
        |> json_response(200)

      assert %{"data" => data} = response
      assert data["id"] == api_key.id
      assert data["permissions"] == ["agents:write"]
    end

    test "denies updates for non-owners", %{authed_conn: conn} do
      other_user = Fixtures.user_fixture()
      {api_key, _token} = Fixtures.api_key_fixture(other_user.id, %{permissions: ["agents:read"]})

      conn
      |> patch("/api/api-keys/#{api_key.id}", %{"permissions" => ["agents:write"]})
      |> json_response(403)
    end
  end
end
