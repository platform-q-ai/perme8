defmodule AgentsApi.AgentApiControllerPermissionTest do
  use AgentsApi.ConnCase

  alias AgentsApi.Test.Fixtures

  @create_params %{
    "name" => "Permission Test Agent",
    "description" => "Agent for permission checks"
  }

  describe "REST permission enforcement" do
    test "GET /api/agents with agents:read returns 200", %{conn: conn} do
      authed_conn = authed_conn(conn, ["agents:read"])

      authed_conn
      |> get("/api/agents")
      |> json_response(200)
    end

    test "GET /api/agents with agents:write only returns 403", %{conn: conn} do
      authed_conn = authed_conn(conn, ["agents:write"])

      response =
        authed_conn
        |> get("/api/agents")
        |> json_response(403)

      assert response == %{"error" => "insufficient_permissions", "required" => "agents:read"}
    end

    test "POST /api/agents with agents:write returns 201", %{conn: conn} do
      authed_conn = authed_conn(conn, ["agents:write"])

      authed_conn
      |> post("/api/agents", @create_params)
      |> json_response(201)
    end

    test "POST /api/agents with agents:read only returns 403", %{conn: conn} do
      authed_conn = authed_conn(conn, ["agents:read"])

      response =
        authed_conn
        |> post("/api/agents", @create_params)
        |> json_response(403)

      assert response == %{"error" => "insufficient_permissions", "required" => "agents:write"}
    end

    test "PATCH /api/agents/:id with agents:write returns 200", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["agents:write"], user)

      authed_conn
      |> patch("/api/agents/#{agent.id}", %{"name" => "Updated"})
      |> json_response(200)
    end

    test "DELETE /api/agents/:id with agents:write returns 200", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["agents:write"], user)

      authed_conn
      |> delete("/api/agents/#{agent.id}")
      |> json_response(200)
    end

    test "POST /api/agents/:id/query with agents:query is allowed", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["agents:query"], user)

      authed_conn
      |> post("/api/agents/#{agent.id}/query", %{})
      |> json_response(422)
    end

    test "POST /api/agents/:id/query with agents:read only returns 403", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["agents:read"], user)

      response =
        authed_conn
        |> post("/api/agents/#{agent.id}/query", %{})
        |> json_response(403)

      assert response == %{"error" => "insufficient_permissions", "required" => "agents:query"}
    end

    test "GET /api/agents/:id/skills with agents:read returns 200", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["agents:read"], user)

      authed_conn
      |> get("/api/agents/#{agent.id}/skills")
      |> json_response(200)
    end

    test "nil permissions allow all endpoints", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, nil, user)

      assert_all_endpoints_allowed(authed_conn, agent.id)
    end

    test "[*] permissions allow all endpoints", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["*"], user)

      assert_all_endpoints_allowed(authed_conn, agent.id)
    end

    test "[agents:*] permissions allow all endpoints", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, ["agents:*"], user)

      assert_all_endpoints_allowed(authed_conn, agent.id)
    end

    test "empty permissions deny all endpoints", %{conn: conn} do
      user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(user.id)
      authed_conn = authed_conn(conn, [], user)

      authed_conn
      |> get("/api/agents")
      |> json_response(403)

      authed_conn
      |> post("/api/agents", @create_params)
      |> json_response(403)

      authed_conn
      |> patch("/api/agents/#{agent.id}", %{"name" => "Denied"})
      |> json_response(403)

      authed_conn
      |> delete("/api/agents/#{agent.id}")
      |> json_response(403)

      authed_conn
      |> post("/api/agents/#{agent.id}/query", %{})
      |> json_response(403)

      authed_conn
      |> get("/api/agents/#{agent.id}/skills")
      |> json_response(403)
    end
  end

  defp assert_all_endpoints_allowed(conn, agent_id) do
    conn
    |> get("/api/agents")
    |> json_response(200)

    conn
    |> post("/api/agents", @create_params)
    |> json_response(201)

    conn
    |> patch("/api/agents/#{agent_id}", %{"name" => "Allowed"})
    |> json_response(200)

    conn
    |> post("/api/agents/#{agent_id}/query", %{})
    |> json_response(422)

    conn
    |> get("/api/agents/#{agent_id}/skills")
    |> json_response(200)

    conn
    |> delete("/api/agents/#{agent_id}")
    |> json_response(200)
  end

  defp authed_conn(conn, permissions, user \\ nil) do
    user = user || Fixtures.user_fixture()
    {_api_key, token} = Fixtures.api_key_fixture(user.id, %{permissions: permissions})

    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
