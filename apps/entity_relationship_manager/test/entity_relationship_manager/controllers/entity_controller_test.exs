defmodule EntityRelationshipManager.EntityControllerTest do
  use EntityRelationshipManager.ConnCase, async: true

  alias EntityRelationshipManager.UseCaseFixtures

  describe "create/2" do
    test "creates an entity and returns 201", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_entity, fn _wid, "Person", %{"name" => "Alice"} -> {:ok, entity} end)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Alice"}
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "Person"
    end

    test "returns 403 for guest role", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Alice"}
        })

      assert json_response(conn, 403)
    end

    test "returns error when schema not found", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:error, :not_found} end)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/entities", %{
          "type" => "Person",
          "properties" => %{"name" => "Alice"}
        })

      assert %{"error" => "no_schema_configured"} = json_response(conn, 422)
    end
  end

  describe "index/2" do
    test "lists entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn _wid, _filters -> {:ok, [entity]} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
    end

    test "lists entities with type filter", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn _wid, %{type: "Person"} -> {:ok, [entity]} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities?type=Person")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
    end

    test "guest can read entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn _wid, _filters -> {:ok, []} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities")

      assert json_response(conn, 200)
    end
  end

  describe "show/2" do
    test "returns a single entity", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, _id, _opts -> {:ok, entity} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == entity.id
    end

    test "returns 404 when entity not found", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity_id = UseCaseFixtures.valid_uuid()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, _id, _opts -> {:error, :not_found} end)

      conn = get(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity_id}")

      assert json_response(conn, 404)
    end
  end

  describe "update/2" do
    test "updates an entity", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id, properties: %{"name" => "Bob"}})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, _id, _opts -> {:ok, entity} end)
      |> expect(:update_entity, fn _wid, _id, _props -> {:ok, entity} end)

      conn =
        put(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity.id}", %{
          "properties" => %{"name" => "Bob"}
        })

      assert %{"data" => _data} = json_response(conn, 200)
    end

    test "returns 403 for guest role", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn, role: :guest)
      entity_id = UseCaseFixtures.valid_uuid()

      conn =
        put(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity_id}", %{
          "properties" => %{"name" => "Bob"}
        })

      assert json_response(conn, 403)
    end
  end

  describe "delete/2" do
    test "soft-deletes an entity", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_entity, fn _wid, _id -> {:ok, entity, 2} end)

      conn = delete(conn, "/api/v1/workspaces/#{ws_id}/entities/#{entity.id}")

      assert %{"data" => _data, "meta" => %{"edges_deleted" => 2}} =
               json_response(conn, 200)
    end
  end

  describe "bulk_create/2" do
    test "bulk creates entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_create_entities, fn _wid, _entities -> {:ok, [entity]} end)

      conn =
        post(conn, "/api/v1/workspaces/#{ws_id}/entities/bulk", %{
          "entities" => [%{"type" => "Person", "properties" => %{"name" => "Alice"}}]
        })

      assert %{"data" => data, "errors" => []} = json_response(conn, 201)
      assert length(data) == 1
    end
  end

  describe "bulk_update/2" do
    test "bulk updates entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)
      entity = UseCaseFixtures.entity(%{workspace_id: ws_id})
      schema = UseCaseFixtures.schema_definition(%{workspace_id: ws_id})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:batch_get_entities, fn _wid, ids ->
        entities_map = Map.new(ids, fn id -> {id, entity} end)
        {:ok, entities_map}
      end)
      |> expect(:bulk_update_entities, fn _wid, _updates -> {:ok, [entity]} end)

      conn =
        put(conn, "/api/v1/workspaces/#{ws_id}/entities/bulk", %{
          "updates" => [%{"id" => entity.id, "properties" => %{"name" => "Bob"}}]
        })

      assert %{"data" => data, "errors" => []} = json_response(conn, 200)
      assert length(data) == 1
    end
  end

  describe "bulk_delete/2" do
    test "bulk deletes entities", %{conn: conn} do
      {conn, ws_id} = authenticated_conn(conn)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_soft_delete_entities, fn _wid, _ids -> {:ok, 2} end)

      conn =
        delete(conn, "/api/v1/workspaces/#{ws_id}/entities/bulk", %{
          "entity_ids" => [UseCaseFixtures.valid_uuid(), UseCaseFixtures.valid_uuid2()]
        })

      assert %{"data" => %{"deleted_count" => 2}} = json_response(conn, 200)
    end
  end
end
