defmodule AgentsApi.AgentApiControllerTest do
  use AgentsApi.ConnCase

  alias AgentsApi.Test.Fixtures

  setup %{conn: conn} do
    user = Fixtures.user_fixture()
    {_api_key, token} = Fixtures.api_key_fixture(user.id)

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, authed_conn: authed_conn, user: user, token: token}
  end

  describe "GET /api/agents (index)" do
    test "lists user's agents", %{authed_conn: conn, user: user} do
      _agent1 = Fixtures.agent_fixture(user.id, %{"name" => "Agent One"})
      _agent2 = Fixtures.agent_fixture(user.id, %{"name" => "Agent Two"})

      response =
        conn
        |> get("/api/agents")
        |> json_response(200)

      assert %{"data" => data} = response
      assert length(data) == 2
      names = Enum.map(data, & &1["name"])
      assert "Agent One" in names
      assert "Agent Two" in names
    end

    test "returns empty list when user has no agents", %{authed_conn: conn} do
      response =
        conn
        |> get("/api/agents")
        |> json_response(200)

      assert %{"data" => []} = response
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn
      |> get("/api/agents")
      |> json_response(401)
    end
  end

  describe "GET /api/agents/:id (show)" do
    test "returns agent owned by user", %{authed_conn: conn, user: user} do
      agent = Fixtures.agent_fixture(user.id, %{"name" => "My Agent", "description" => "Test"})

      response =
        conn
        |> get("/api/agents/#{agent.id}")
        |> json_response(200)

      assert %{"data" => data} = response
      assert data["id"] == agent.id
      assert data["name"] == "My Agent"
      assert data["description"] == "Test"
    end

    test "returns 404 for non-existent agent", %{authed_conn: conn} do
      response =
        conn
        |> get("/api/agents/#{Ecto.UUID.generate()}")
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end

    test "returns 404 for agent owned by another user", %{authed_conn: conn} do
      other_user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(other_user.id)

      response =
        conn
        |> get("/api/agents/#{agent.id}")
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end
  end

  describe "POST /api/agents (create)" do
    test "creates agent with valid params", %{authed_conn: conn} do
      params = %{
        "name" => "New Agent",
        "description" => "A test agent",
        "model" => "gpt-4",
        "temperature" => 0.8
      }

      response =
        conn
        |> post("/api/agents", params)
        |> json_response(201)

      assert %{"data" => data} = response
      assert data["name"] == "New Agent"
      assert data["description"] == "A test agent"
      assert data["model"] == "gpt-4"
      assert data["temperature"] == 0.8
      assert data["id"] != nil
    end

    test "returns 422 for missing required name", %{authed_conn: conn} do
      params = %{"description" => "No name"}

      response =
        conn
        |> post("/api/agents", params)
        |> json_response(422)

      assert %{"errors" => errors} = response
      assert errors["name"] != nil
    end

    test "returns 401 without authentication", %{conn: conn} do
      conn
      |> post("/api/agents", %{"name" => "Test"})
      |> json_response(401)
    end
  end

  describe "PATCH /api/agents/:id (update)" do
    test "updates agent with valid params", %{authed_conn: conn, user: user} do
      agent = Fixtures.agent_fixture(user.id, %{"name" => "Old Name"})

      response =
        conn
        |> patch("/api/agents/#{agent.id}", %{"name" => "New Name"})
        |> json_response(200)

      assert %{"data" => data} = response
      assert data["name"] == "New Name"
    end

    test "returns 404 for non-existent agent", %{authed_conn: conn} do
      response =
        conn
        |> patch("/api/agents/#{Ecto.UUID.generate()}", %{"name" => "New Name"})
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end

    test "returns 404 for agent owned by another user", %{authed_conn: conn} do
      other_user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(other_user.id)

      response =
        conn
        |> patch("/api/agents/#{agent.id}", %{"name" => "Hacked"})
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end
  end

  describe "DELETE /api/agents/:id (delete)" do
    test "deletes agent owned by user", %{authed_conn: conn, user: user} do
      agent = Fixtures.agent_fixture(user.id, %{"name" => "To Delete"})

      response =
        conn
        |> delete("/api/agents/#{agent.id}")
        |> json_response(200)

      assert %{"data" => data} = response
      assert data["id"] == agent.id

      # Verify it's actually deleted
      response =
        conn
        |> get("/api/agents/#{agent.id}")
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end

    test "returns 404 for non-existent agent", %{authed_conn: conn} do
      response =
        conn
        |> delete("/api/agents/#{Ecto.UUID.generate()}")
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end

    test "returns 404 for agent owned by another user", %{authed_conn: conn} do
      other_user = Fixtures.user_fixture()
      agent = Fixtures.agent_fixture(other_user.id)

      response =
        conn
        |> delete("/api/agents/#{agent.id}")
        |> json_response(404)

      assert %{"error" => "Agent not found"} = response
    end
  end
end
