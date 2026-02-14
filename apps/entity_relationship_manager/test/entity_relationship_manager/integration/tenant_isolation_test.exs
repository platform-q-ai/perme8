defmodule EntityRelationshipManager.Integration.TenantIsolationTest do
  @moduledoc """
  Integration test verifying multi-tenancy (workspace) isolation.

  Validates that:
    - Entities from workspace A are NOT visible in workspace B
    - Edges from workspace A are NOT visible in workspace B
    - Traversal in workspace A does NOT cross into workspace B
    - The API returns 404 (not 403) for cross-workspace access attempts
    - Schema from workspace A does NOT affect workspace B

  Tagged `:integration` so it is excluded by default. Enable with:

      mix test --include integration

  These tests document the expected workspace isolation behavior through
  the HTTP API layer. Each workspace gets its own authenticated conn with
  a distinct workspace_id.
  """

  use EntityRelationshipManager.ConnCase, async: true

  @moduletag :integration

  alias EntityRelationshipManager.UseCaseFixtures
  alias EntityRelationshipManager.Domain.Entities.{Entity, Edge}

  describe "workspace entity isolation" do
    test "entities created in workspace A are not visible in workspace B", %{conn: conn} do
      {conn_a, ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      now = DateTime.utc_now()
      entity_a_id = Ecto.UUID.generate()

      entity_a =
        Entity.new(%{
          id: entity_a_id,
          workspace_id: ws_a,
          type: "Person",
          properties: %{"name" => "Alice in A"},
          created_at: now,
          updated_at: now
        })

      # Workspace A has one entity
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn wid, _filters ->
        assert wid == ws_a
        {:ok, [entity_a]}
      end)

      resp_conn = get(conn_a, ~p"/api/v1/workspaces/#{ws_a}/entities")
      assert %{"data" => entities_a} = json_response(resp_conn, 200)
      assert length(entities_a) == 1
      assert hd(entities_a)["id"] == entity_a_id

      # Workspace B has no entities
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn wid, _filters ->
        assert wid == ws_b
        {:ok, []}
      end)

      resp_conn = get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities")
      assert %{"data" => entities_b} = json_response(resp_conn, 200)
      assert entities_b == []
    end

    test "getting an entity by ID from wrong workspace returns 404", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      entity_a_id = Ecto.UUID.generate()

      # Entity exists in workspace A but we query workspace B
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn wid, eid, _opts ->
        assert wid == ws_b
        assert eid == entity_a_id
        # The repository scopes by workspace — entity not found
        {:error, :not_found}
      end)

      resp_conn = get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities/#{entity_a_id}")

      # Must return 404 (not 403) to avoid leaking entity existence
      assert json_response(resp_conn, 404)
    end

    test "updating an entity from wrong workspace returns 404", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      entity_a_id = Ecto.UUID.generate()
      schema_b = UseCaseFixtures.schema_definition(%{workspace_id: ws_b})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema_b} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn wid, eid, _opts ->
        assert wid == ws_b
        assert eid == entity_a_id
        {:error, :not_found}
      end)

      resp_conn =
        put(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities/#{entity_a_id}", %{
          "properties" => %{"name" => "Hacked!"}
        })

      assert json_response(resp_conn, 404)
    end

    test "deleting an entity from wrong workspace returns 404", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      entity_a_id = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_entity, fn wid, eid ->
        assert wid == ws_b
        assert eid == entity_a_id
        {:error, :not_found}
      end)

      resp_conn = delete(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities/#{entity_a_id}")

      assert json_response(resp_conn, 404)
    end
  end

  describe "workspace edge isolation" do
    test "edges from workspace A are not visible in workspace B", %{conn: conn} do
      {conn_a, ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      now = DateTime.utc_now()
      edge_a_id = Ecto.UUID.generate()

      edge_a =
        Edge.new(%{
          id: edge_a_id,
          workspace_id: ws_a,
          type: "WORKS_AT",
          source_id: Ecto.UUID.generate(),
          target_id: Ecto.UUID.generate(),
          properties: %{"role" => "Engineer"},
          created_at: now,
          updated_at: now
        })

      # Workspace A has one edge
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn wid, _filters ->
        assert wid == ws_a
        {:ok, [edge_a]}
      end)

      resp_conn = get(conn_a, ~p"/api/v1/workspaces/#{ws_a}/edges")
      assert %{"data" => edges_a} = json_response(resp_conn, 200)
      assert length(edges_a) == 1

      # Workspace B has no edges
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn wid, _filters ->
        assert wid == ws_b
        {:ok, []}
      end)

      resp_conn = get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/edges")
      assert %{"data" => edges_b} = json_response(resp_conn, 200)
      assert edges_b == []
    end

    test "getting an edge by ID from wrong workspace returns 404", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      edge_a_id = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn wid, eid ->
        assert wid == ws_b
        assert eid == edge_a_id
        {:error, :not_found}
      end)

      resp_conn = get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/edges/#{edge_a_id}")

      # 404, not 403 — no information leakage
      assert json_response(resp_conn, 404)
    end

    test "deleting an edge from wrong workspace returns 404", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      edge_a_id = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_edge, fn wid, eid ->
        assert wid == ws_b
        assert eid == edge_a_id
        {:error, :not_found}
      end)

      resp_conn = delete(conn_b, ~p"/api/v1/workspaces/#{ws_b}/edges/#{edge_a_id}")

      assert json_response(resp_conn, 404)
    end
  end

  describe "workspace traversal isolation" do
    test "neighbors query in workspace B does not return entities from workspace A",
         %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      entity_b_id = Ecto.UUID.generate()

      # Workspace B traversal returns empty — entities from A not leaked
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn wid, eid, _opts ->
        assert wid == ws_b
        assert eid == entity_b_id
        {:ok, []}
      end)

      resp_conn =
        get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities/#{entity_b_id}/neighbors")

      assert %{"data" => neighbors} = json_response(resp_conn, 200)
      assert neighbors == []
    end

    test "path finding in workspace B does not cross into workspace A",
         %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      source_b = Ecto.UUID.generate()
      target_b = Ecto.UUID.generate()

      # No paths found — workspace boundary is respected
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:find_paths, fn wid, sid, tid, _opts ->
        assert wid == ws_b
        assert sid == source_b
        assert tid == target_b
        {:ok, []}
      end)

      resp_conn =
        get(
          conn_b,
          ~p"/api/v1/workspaces/#{ws_b}/entities/#{source_b}/paths/#{target_b}"
        )

      assert %{"data" => paths} = json_response(resp_conn, 200)
      assert paths == []
    end

    test "traverse in workspace B does not include entities from workspace A",
         %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      start_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      entity_b =
        Entity.new(%{
          id: start_id,
          workspace_id: ws_b,
          type: "Person",
          properties: %{"name" => "Bob in B"},
          created_at: now,
          updated_at: now
        })

      # Traversal scoped to workspace B only
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:traverse, fn wid, sid, _opts ->
        assert wid == ws_b
        assert sid == start_id
        {:ok, [entity_b]}
      end)

      resp_conn =
        get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/traverse?start_id=#{start_id}")

      assert %{"data" => traversed} = json_response(resp_conn, 200)
      assert length(traversed) == 1
      # All returned entities belong to workspace B
      assert hd(traversed)["workspace_id"] == ws_b
    end
  end

  describe "workspace schema isolation" do
    test "schema from workspace A is not accessible from workspace B", %{conn: conn} do
      {conn_a, ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      schema_a = UseCaseFixtures.schema_definition(%{workspace_id: ws_a})

      # Workspace A has a schema
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn wid ->
        assert wid == ws_a
        {:ok, schema_a}
      end)

      resp_conn = get(conn_a, ~p"/api/v1/workspaces/#{ws_a}/schema")
      assert %{"data" => _} = json_response(resp_conn, 200)

      # Workspace B has no schema
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn wid ->
        assert wid == ws_b
        {:error, :not_found}
      end)

      resp_conn = get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/schema")
      assert json_response(resp_conn, 404)
    end

    test "workspace A schema does not allow creating entities in workspace B",
         %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      # Workspace B has no schema — entity creation should fail
      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn wid ->
        assert wid == ws_b
        {:error, :not_found}
      end)

      resp_conn =
        post(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Should not work"}
        })

      assert json_response(resp_conn, 404)
    end
  end

  describe "cross-workspace access returns 404 (not 403)" do
    test "API returns 404 for entity access across workspace boundary", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      entity_from_a = Ecto.UUID.generate()

      # Attempting to access workspace A's entity via workspace B's API
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn wid, _eid, _opts ->
        # Repository is always scoped by workspace_id
        assert wid == ws_b
        {:error, :not_found}
      end)

      resp_conn =
        get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/entities/#{entity_from_a}")

      response = json_response(resp_conn, 404)
      # Verify we get 404, not 403 — prevents information leakage
      assert response["error"] == "not_found"
      refute Map.has_key?(response, "forbidden")
    end

    test "API returns 404 for edge access across workspace boundary", %{conn: conn} do
      {_conn_a, _ws_a} = authenticated_conn(conn)
      {conn_b, ws_b} = authenticated_conn(conn)

      edge_from_a = Ecto.UUID.generate()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn wid, _eid ->
        assert wid == ws_b
        {:error, :not_found}
      end)

      resp_conn = get(conn_b, ~p"/api/v1/workspaces/#{ws_b}/edges/#{edge_from_a}")

      response = json_response(resp_conn, 404)
      assert response["error"] == "not_found"
    end
  end
end
