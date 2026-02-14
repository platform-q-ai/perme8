defmodule EntityRelationshipManager.Infrastructure.Repositories.GraphRepositoryTest do
  use ExUnit.Case, async: true

  @moduletag :neo4j

  alias EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Entities.Edge

  @workspace_id "ws-test-001"
  @entity_id "ent-001"
  @entity_id2 "ent-002"
  @edge_id "edge-001"

  defp stub_adapter(responses) do
    # Build a dynamic adapter module that returns responses based on query patterns
    test_pid = self()

    {:ok, agent} = Agent.start_link(fn -> responses end)

    adapter_module = Module.concat([__MODULE__, "Adapter#{System.unique_integer([:positive])}"])

    Module.create(
      adapter_module,
      quote do
        def execute(cypher, params) do
          send(unquote(test_pid), {:cypher_executed, cypher, params})
          response = Agent.get(unquote(agent), fn responses -> responses end)

          case response do
            fun when is_function(fun, 2) -> fun.(cypher, params)
            result -> result
          end
        end
      end,
      Macro.Env.location(__ENV__)
    )

    adapter_module
  end

  # ── Entity CRUD ──────────────────────────────────────────────────────

  describe "create_entity/4" do
    test "builds parameterized CREATE query and returns entity" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Alice"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Entity{} = entity} =
               GraphRepository.create_entity(@workspace_id, "Person", %{"name" => "Alice"},
                 adapter: adapter
               )

      assert entity.id == @entity_id
      assert entity.type == "Person"
      assert entity.workspace_id == @workspace_id
      assert entity.properties == %{"name" => "Alice"}

      # Verify parameterized query was sent
      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "CREATE"
      assert cypher =~ "$_workspace_id"
      assert params._workspace_id == @workspace_id
      assert params.type == "Person"
    end
  end

  describe "get_entity/3" do
    test "returns entity when found" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Alice"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Entity{id: @entity_id}} =
               GraphRepository.get_entity(@workspace_id, @entity_id, adapter: adapter)

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "MATCH"
      assert params._workspace_id == @workspace_id
      assert params.id == @entity_id
    end

    test "returns {:error, :not_found} when no records" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:error, :not_found} =
               GraphRepository.get_entity(@workspace_id, @entity_id, adapter: adapter)
    end
  end

  describe "list_entities/3" do
    test "returns list of entities with type filter" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Alice"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, [%Entity{}]} =
               GraphRepository.list_entities(@workspace_id, %{type: "Person"}, adapter: adapter)

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "MATCH"
      assert params._workspace_id == @workspace_id
    end

    test "returns empty list when no entities match" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:ok, []} =
               GraphRepository.list_entities(@workspace_id, %{}, adapter: adapter)
    end
  end

  describe "update_entity/4" do
    test "builds parameterized SET query and returns updated entity" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Bob"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Entity{properties: %{"name" => "Bob"}}} =
               GraphRepository.update_entity(@workspace_id, @entity_id, %{"name" => "Bob"},
                 adapter: adapter
               )

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "SET"
      assert params._workspace_id == @workspace_id
      assert params.id == @entity_id
    end

    test "returns {:error, :not_found} when entity not found" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:error, :not_found} =
               GraphRepository.update_entity(@workspace_id, @entity_id, %{"name" => "Bob"},
                 adapter: adapter
               )
    end
  end

  describe "soft_delete_entity/3" do
    test "sets deleted_at and cascades to edges" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Alice"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now),
                 "deleted_at" => DateTime.to_iso8601(now),
                 "deleted_edge_count" => 3
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Entity{deleted_at: deleted_at}, 3} =
               GraphRepository.soft_delete_entity(@workspace_id, @entity_id, adapter: adapter)

      assert deleted_at != nil

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "deleted_at"
      assert params._workspace_id == @workspace_id
    end

    test "returns {:error, :not_found} when entity not found" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:error, :not_found} =
               GraphRepository.soft_delete_entity(@workspace_id, @entity_id, adapter: adapter)
    end
  end

  # ── Edge CRUD ──────────────────────────────────────────────────────

  describe "create_edge/6" do
    test "builds parameterized CREATE relationship query" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @edge_id,
                 "type" => "WORKS_AT",
                 "source_id" => @entity_id,
                 "target_id" => @entity_id2,
                 "properties" => %{"role" => "Engineer"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Edge{} = edge} =
               GraphRepository.create_edge(
                 @workspace_id,
                 "WORKS_AT",
                 @entity_id,
                 @entity_id2,
                 %{"role" => "Engineer"},
                 adapter: adapter
               )

      assert edge.type == "WORKS_AT"
      assert edge.source_id == @entity_id
      assert edge.target_id == @entity_id2

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "CREATE"
      assert cypher =~ "$_workspace_id"
      assert params.source_id == @entity_id
      assert params.target_id == @entity_id2
    end
  end

  describe "get_edge/3" do
    test "returns edge when found" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @edge_id,
                 "type" => "WORKS_AT",
                 "source_id" => @entity_id,
                 "target_id" => @entity_id2,
                 "properties" => %{"role" => "Engineer"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Edge{id: @edge_id}} =
               GraphRepository.get_edge(@workspace_id, @edge_id, adapter: adapter)
    end

    test "returns {:error, :not_found} when no records" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:error, :not_found} =
               GraphRepository.get_edge(@workspace_id, @edge_id, adapter: adapter)
    end
  end

  describe "list_edges/3" do
    test "returns list of edges" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @edge_id,
                 "type" => "WORKS_AT",
                 "source_id" => @entity_id,
                 "target_id" => @entity_id2,
                 "properties" => %{},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, [%Edge{}]} =
               GraphRepository.list_edges(@workspace_id, %{}, adapter: adapter)
    end
  end

  describe "update_edge/4" do
    test "builds parameterized SET query for edge" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @edge_id,
                 "type" => "WORKS_AT",
                 "source_id" => @entity_id,
                 "target_id" => @entity_id2,
                 "properties" => %{"role" => "Senior Engineer"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Edge{properties: %{"role" => "Senior Engineer"}}} =
               GraphRepository.update_edge(
                 @workspace_id,
                 @edge_id,
                 %{"role" => "Senior Engineer"}, adapter: adapter)
    end

    test "returns {:error, :not_found} when edge not found" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:error, :not_found} =
               GraphRepository.update_edge(@workspace_id, @edge_id, %{}, adapter: adapter)
    end
  end

  describe "soft_delete_edge/3" do
    test "sets deleted_at on edge" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @edge_id,
                 "type" => "WORKS_AT",
                 "source_id" => @entity_id,
                 "target_id" => @entity_id2,
                 "properties" => %{},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now),
                 "deleted_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, %Edge{deleted_at: deleted_at}} =
               GraphRepository.soft_delete_edge(@workspace_id, @edge_id, adapter: adapter)

      assert deleted_at != nil
    end

    test "returns {:error, :not_found} when edge not found" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      assert {:error, :not_found} =
               GraphRepository.soft_delete_edge(@workspace_id, @edge_id, adapter: adapter)
    end
  end

  # ── Traversal ──────────────────────────────────────────────────────

  describe "get_neighbors/3" do
    test "returns neighboring entities" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id2,
                 "type" => "Company",
                 "properties" => %{"name" => "Acme"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, [%Entity{id: @entity_id2}]} =
               GraphRepository.get_neighbors(@workspace_id, @entity_id,
                 adapter: adapter,
                 direction: :outgoing
               )

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "MATCH"
      assert params._workspace_id == @workspace_id
      assert params.id == @entity_id
    end
  end

  describe "find_paths/4" do
    test "returns paths between two entities" do
      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "path" => [@entity_id, @edge_id, @entity_id2]
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, paths} =
               GraphRepository.find_paths(@workspace_id, @entity_id, @entity_id2,
                 adapter: adapter,
                 max_depth: 5
               )

      assert is_list(paths)

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "shortestPath" or cypher =~ "allShortestPaths"
      assert params.source_id == @entity_id
      assert params.target_id == @entity_id2
    end
  end

  describe "traverse/3" do
    test "returns entities from traversal" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               },
               %{
                 "id" => @entity_id2,
                 "type" => "Company",
                 "properties" => %{},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      assert {:ok, entities} =
               GraphRepository.traverse(@workspace_id, @entity_id,
                 adapter: adapter,
                 max_depth: 3
               )

      assert length(entities) == 2
      assert Enum.all?(entities, &match?(%Entity{}, &1))
    end
  end

  # ── Bulk operations ──────────────────────────────────────────────────

  describe "bulk_create_entities/3" do
    test "creates multiple entities" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Alice"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               },
               %{
                 "id" => @entity_id2,
                 "type" => "Person",
                 "properties" => %{"name" => "Bob"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      entities_data = [
        %{type: "Person", properties: %{"name" => "Alice"}},
        %{type: "Person", properties: %{"name" => "Bob"}}
      ]

      assert {:ok, entities} =
               GraphRepository.bulk_create_entities(@workspace_id, entities_data,
                 adapter: adapter
               )

      assert length(entities) == 2

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "UNWIND"
      assert params._workspace_id == @workspace_id
    end
  end

  describe "bulk_create_edges/3" do
    test "creates multiple edges" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @edge_id,
                 "type" => "WORKS_AT",
                 "source_id" => @entity_id,
                 "target_id" => @entity_id2,
                 "properties" => %{},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      edges_data = [
        %{type: "WORKS_AT", source_id: @entity_id, target_id: @entity_id2, properties: %{}}
      ]

      assert {:ok, edges} =
               GraphRepository.bulk_create_edges(@workspace_id, edges_data, adapter: adapter)

      assert length(edges) == 1

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "UNWIND"
      assert params._workspace_id == @workspace_id
    end
  end

  describe "bulk_update_entities/3" do
    test "updates multiple entities" do
      now = DateTime.utc_now()

      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [
               %{
                 "id" => @entity_id,
                 "type" => "Person",
                 "properties" => %{"name" => "Alice Updated"},
                 "created_at" => DateTime.to_iso8601(now),
                 "updated_at" => DateTime.to_iso8601(now)
               }
             ],
             summary: %{}
           }}
        )

      updates = [
        %{id: @entity_id, properties: %{"name" => "Alice Updated"}}
      ]

      assert {:ok, entities} =
               GraphRepository.bulk_update_entities(@workspace_id, updates, adapter: adapter)

      assert length(entities) == 1

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "UNWIND"
      assert params._workspace_id == @workspace_id
    end
  end

  describe "bulk_soft_delete_entities/3" do
    test "soft deletes multiple entities and returns count" do
      adapter =
        stub_adapter(
          {:ok,
           %{
             records: [%{"deleted_count" => 2}],
             summary: %{}
           }}
        )

      assert {:ok, 2} =
               GraphRepository.bulk_soft_delete_entities(@workspace_id, [@entity_id, @entity_id2],
                 adapter: adapter
               )

      assert_received {:cypher_executed, cypher, params}
      assert cypher =~ "deleted_at"
      assert params._workspace_id == @workspace_id
    end
  end

  # ── Health check ──────────────────────────────────────────────────────

  describe "health_check/1" do
    test "delegates to Neo4jAdapter" do
      defmodule HealthCheckAdapter do
        def execute(_cypher, _params) do
          {:ok, %{records: [%{"health" => 1}], summary: %{}}}
        end
      end

      assert :ok = GraphRepository.health_check(adapter: HealthCheckAdapter)
    end
  end

  # ── Workspace scoping ──────────────────────────────────────────────────

  describe "workspace scoping" do
    test "all queries include workspace_id parameter" do
      adapter = stub_adapter({:ok, %{records: [], summary: %{}}})

      # Try various operations and verify all include workspace_id
      GraphRepository.list_entities(@workspace_id, %{}, adapter: adapter)
      assert_received {:cypher_executed, _cypher, %{_workspace_id: @workspace_id}}

      GraphRepository.list_edges(@workspace_id, %{}, adapter: adapter)
      assert_received {:cypher_executed, _cypher, %{_workspace_id: @workspace_id}}

      GraphRepository.get_entity(@workspace_id, @entity_id, adapter: adapter)
      assert_received {:cypher_executed, _cypher, %{_workspace_id: @workspace_id}}

      GraphRepository.get_edge(@workspace_id, @edge_id, adapter: adapter)
      assert_received {:cypher_executed, _cypher, %{_workspace_id: @workspace_id}}
    end
  end
end
