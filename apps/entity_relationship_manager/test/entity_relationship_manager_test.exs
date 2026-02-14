defmodule EntityRelationshipManagerTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  setup do
    %{workspace_id: "ws-test-001"}
  end

  describe "get_schema/2" do
    test "delegates to GetSchema use case", %{workspace_id: ws_id} do
      schema = UseCaseFixtures.schema_definition()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn wid ->
        assert wid == ws_id
        {:ok, schema}
      end)

      assert {:ok, ^schema} =
               EntityRelationshipManager.get_schema(ws_id,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock
               )
    end
  end

  describe "upsert_schema/3" do
    test "delegates to UpsertSchema use case", %{workspace_id: ws_id} do
      schema = UseCaseFixtures.schema_definition()

      attrs = %{
        entity_types: [
          %{
            "name" => "Person",
            "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
          }
        ],
        edge_types: []
      }

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:upsert_schema, fn wid, _a ->
        assert wid == ws_id
        {:ok, schema}
      end)

      assert {:ok, ^schema} =
               EntityRelationshipManager.upsert_schema(ws_id, attrs,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock
               )
    end
  end

  describe "create_entity/3" do
    test "delegates to CreateEntity use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()
      schema = UseCaseFixtures.schema_definition()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn wid ->
        assert wid == ws_id
        {:ok, schema}
      end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_entity, fn wid, "Person", %{"name" => "Alice"} ->
        assert wid == ws_id
        {:ok, entity}
      end)

      attrs = %{type: "Person", properties: %{"name" => "Alice"}}

      assert {:ok, ^entity} =
               EntityRelationshipManager.create_entity(ws_id, attrs,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "get_entity/3" do
    test "delegates to GetEntity use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()
      entity_id = entity.id

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn wid, eid, _opts ->
        assert wid == ws_id
        assert eid == entity_id
        {:ok, entity}
      end)

      assert {:ok, ^entity} =
               EntityRelationshipManager.get_entity(ws_id, entity_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "list_entities/3" do
    test "delegates to ListEntities use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_entities, fn wid, filters ->
        assert wid == ws_id
        assert filters == %{type: "Person"}
        {:ok, [entity]}
      end)

      assert {:ok, [^entity]} =
               EntityRelationshipManager.list_entities(ws_id, %{type: "Person"},
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "update_entity/4" do
    test "delegates to UpdateEntity use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity(%{properties: %{"name" => "Bob"}})
      schema = UseCaseFixtures.schema_definition()
      entity_id = entity.id

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_entity, fn _wid, _eid, _opts -> {:ok, entity} end)
      |> expect(:update_entity, fn wid, eid, props ->
        assert wid == ws_id
        assert eid == entity_id
        assert props == %{"name" => "Bob"}
        {:ok, entity}
      end)

      assert {:ok, ^entity} =
               EntityRelationshipManager.update_entity(
                 ws_id,
                 entity_id,
                 %{"name" => "Bob"},
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "delete_entity/3" do
    test "delegates to DeleteEntity use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()
      entity_id = entity.id

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_entity, fn wid, eid ->
        assert wid == ws_id
        assert eid == entity_id
        {:ok, entity, 2}
      end)

      assert {:ok, ^entity, 2} =
               EntityRelationshipManager.delete_entity(ws_id, entity_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "create_edge/3" do
    test "delegates to CreateEdge use case", %{workspace_id: ws_id} do
      edge = UseCaseFixtures.edge()
      schema = UseCaseFixtures.schema_definition()
      source = UseCaseFixtures.entity()
      target = UseCaseFixtures.entity(%{id: UseCaseFixtures.valid_uuid2()})

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:create_edge, fn _wid, "WORKS_AT", _s, _t, _p -> {:ok, edge} end)

      attrs = %{
        type: "WORKS_AT",
        source_id: source.id,
        target_id: target.id,
        properties: %{"role" => "Engineer"}
      }

      assert {:ok, ^edge} =
               EntityRelationshipManager.create_edge(ws_id, attrs,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "get_edge/3" do
    test "delegates to GetEdge use case", %{workspace_id: ws_id} do
      edge = UseCaseFixtures.edge()
      edge_id = edge.id

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn _wid, eid ->
        assert eid == edge_id
        {:ok, edge}
      end)

      assert {:ok, ^edge} =
               EntityRelationshipManager.get_edge(ws_id, edge_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "list_edges/3" do
    test "delegates to ListEdges use case", %{workspace_id: ws_id} do
      edge = UseCaseFixtures.edge()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:list_edges, fn _wid, _filters -> {:ok, [edge]} end)

      assert {:ok, [^edge]} =
               EntityRelationshipManager.list_edges(ws_id, %{},
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "update_edge/4" do
    test "delegates to UpdateEdge use case", %{workspace_id: ws_id} do
      edge = UseCaseFixtures.edge(%{properties: %{"role" => "CTO"}})
      schema = UseCaseFixtures.schema_definition()
      edge_id = edge.id

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_edge, fn _wid, _eid -> {:ok, edge} end)
      |> expect(:update_edge, fn _wid, _eid, _props -> {:ok, edge} end)

      assert {:ok, ^edge} =
               EntityRelationshipManager.update_edge(
                 ws_id,
                 edge_id,
                 %{"role" => "CTO"},
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "delete_edge/3" do
    test "delegates to DeleteEdge use case", %{workspace_id: ws_id} do
      edge = UseCaseFixtures.edge()
      edge_id = edge.id

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:soft_delete_edge, fn _wid, eid ->
        assert eid == edge_id
        {:ok, edge}
      end)

      assert {:ok, ^edge} =
               EntityRelationshipManager.delete_edge(ws_id, edge_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "get_neighbors/3" do
    test "delegates to GetNeighbors use case", %{workspace_id: ws_id} do
      entity_id = UseCaseFixtures.valid_uuid()
      neighbor = UseCaseFixtures.entity(%{id: UseCaseFixtures.valid_uuid2()})

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:get_neighbors, fn _wid, eid, _opts ->
        assert eid == entity_id
        {:ok, [neighbor]}
      end)

      assert {:ok, [^neighbor]} =
               EntityRelationshipManager.get_neighbors(ws_id, entity_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "find_paths/4" do
    test "delegates to FindPaths use case", %{workspace_id: ws_id} do
      source_id = UseCaseFixtures.valid_uuid()
      target_id = UseCaseFixtures.valid_uuid2()

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:find_paths, fn _wid, sid, tid, _opts ->
        assert sid == source_id
        assert tid == target_id
        {:ok, [[source_id, target_id]]}
      end)

      assert {:ok, _paths} =
               EntityRelationshipManager.find_paths(ws_id, source_id, target_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "traverse/2" do
    test "delegates to Traverse use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()
      start_id = entity.id

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:traverse, fn _wid, sid, _opts ->
        assert sid == start_id
        {:ok, [entity]}
      end)

      assert {:ok, [^entity]} =
               EntityRelationshipManager.traverse(ws_id,
                 start_id: start_id,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "bulk_create_entities/3" do
    test "delegates to BulkCreateEntities use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()
      schema = UseCaseFixtures.schema_definition()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_create_entities, fn _wid, _entities -> {:ok, [entity]} end)

      entities = [%{type: "Person", properties: %{"name" => "Alice"}}]

      assert {:ok, [^entity]} =
               EntityRelationshipManager.bulk_create_entities(ws_id, entities,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "bulk_update_entities/3" do
    test "delegates to BulkUpdateEntities use case", %{workspace_id: ws_id} do
      entity = UseCaseFixtures.entity()
      schema = UseCaseFixtures.schema_definition()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:batch_get_entities, fn _wid, ids ->
        entities_map = Map.new(ids, fn id -> {id, entity} end)
        {:ok, entities_map}
      end)
      |> expect(:bulk_update_entities, fn _wid, _updates -> {:ok, [entity]} end)

      updates = [%{id: entity.id, properties: %{"name" => "Bob"}}]

      assert {:ok, [^entity]} =
               EntityRelationshipManager.bulk_update_entities(ws_id, updates,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "bulk_delete_entities/3" do
    test "delegates to BulkDeleteEntities use case", %{workspace_id: ws_id} do
      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_soft_delete_entities, fn _wid, _ids -> {:ok, 2} end)

      entity_ids = [UseCaseFixtures.valid_uuid(), UseCaseFixtures.valid_uuid2()]

      assert {:ok, 2} =
               EntityRelationshipManager.bulk_delete_entities(ws_id, entity_ids,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end

  describe "bulk_create_edges/3" do
    test "delegates to BulkCreateEdges use case", %{workspace_id: ws_id} do
      edge = UseCaseFixtures.edge()
      schema = UseCaseFixtures.schema_definition()

      EntityRelationshipManager.Mocks.SchemaRepositoryMock
      |> expect(:get_schema, fn _wid -> {:ok, schema} end)

      EntityRelationshipManager.Mocks.GraphRepositoryMock
      |> expect(:bulk_create_edges, fn _wid, _edges -> {:ok, [edge]} end)

      edges = [
        %{
          type: "WORKS_AT",
          source_id: UseCaseFixtures.valid_uuid(),
          target_id: UseCaseFixtures.valid_uuid2(),
          properties: %{"role" => "Engineer"}
        }
      ]

      assert {:ok, [^edge]} =
               EntityRelationshipManager.bulk_create_edges(ws_id, edges,
                 schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
                 graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
               )
    end
  end
end
