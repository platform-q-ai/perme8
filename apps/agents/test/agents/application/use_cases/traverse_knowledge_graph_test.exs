defmodule Agents.Application.UseCases.TraverseKnowledgeGraphTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.UseCases.TraverseKnowledgeGraph
  alias Agents.Domain.Entities.KnowledgeEntry
  alias Agents.Mocks.ErmGatewayMock

  import Agents.Test.KnowledgeFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "traverses from starting entry, returns reachable entries" do
      start_id = unique_id()
      start_entity = erm_knowledge_entity(%{id: start_id})
      neighbor1 = erm_knowledge_entity(%{id: unique_id()})
      neighbor2 = erm_knowledge_entity(%{id: unique_id()})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, eid ->
        assert eid == start_id
        {:ok, start_entity}
      end)
      |> expect(:traverse, fn _ws_id, sid, opts ->
        assert sid == start_id
        assert Keyword.get(opts, :max_depth) == 2
        {:ok, [neighbor1, neighbor2]}
      end)

      assert {:ok, results} =
               TraverseKnowledgeGraph.execute(workspace_id(), %{start_id: start_id},
                 erm_gateway: ErmGatewayMock
               )

      assert length(results) == 2
      assert Enum.all?(results, &match?(%KnowledgeEntry{}, &1))
    end

    test "filters by relationship type when specified" do
      start_id = unique_id()
      start_entity = erm_knowledge_entity(%{id: start_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, start_entity} end)
      |> expect(:traverse, fn _ws_id, _sid, opts ->
        assert Keyword.get(opts, :edge_type) == "depends_on"
        {:ok, []}
      end)

      assert {:ok, []} =
               TraverseKnowledgeGraph.execute(
                 workspace_id(),
                 %{start_id: start_id, relationship_type: "depends_on"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "uses default depth of 2 when not specified" do
      start_id = unique_id()
      start_entity = erm_knowledge_entity(%{id: start_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, start_entity} end)
      |> expect(:traverse, fn _ws_id, _sid, opts ->
        assert Keyword.get(opts, :max_depth) == 2
        {:ok, []}
      end)

      assert {:ok, _} =
               TraverseKnowledgeGraph.execute(workspace_id(), %{start_id: start_id},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "clamps depth to max 5" do
      start_id = unique_id()
      start_entity = erm_knowledge_entity(%{id: start_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, start_entity} end)
      |> expect(:traverse, fn _ws_id, _sid, opts ->
        assert Keyword.get(opts, :max_depth) == 5
        {:ok, []}
      end)

      assert {:ok, _} =
               TraverseKnowledgeGraph.execute(workspace_id(), %{start_id: start_id, depth: 100},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :not_found} for non-existent starting entry" do
      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:error, :not_found} end)

      assert {:error, :not_found} =
               TraverseKnowledgeGraph.execute(workspace_id(), %{start_id: "nonexistent"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :missing_required_param} when start_id is missing" do
      assert {:error, :missing_required_param} =
               TraverseKnowledgeGraph.execute(workspace_id(), %{}, erm_gateway: ErmGatewayMock)
    end

    test "returns {:error, :invalid_relationship_type} for bad relationship type" do
      assert {:error, :invalid_relationship_type} =
               TraverseKnowledgeGraph.execute(
                 workspace_id(),
                 %{start_id: unique_id(), relationship_type: "bad_type"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "converts ERM results to KnowledgeEntry domain objects" do
      start_id = unique_id()
      start_entity = erm_knowledge_entity(%{id: start_id})

      neighbor =
        erm_knowledge_entity(%{
          id: "neighbor-1",
          properties: %{
            "title" => "Neighbor",
            "body" => "Content",
            "category" => "concept",
            "tags" => Jason.encode!(["test"]),
            "code_snippets" => "[]",
            "file_paths" => "[]",
            "external_links" => "[]",
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, start_entity} end)
      |> expect(:traverse, fn _ws_id, _sid, _opts -> {:ok, [neighbor]} end)

      assert {:ok, [%KnowledgeEntry{id: "neighbor-1", title: "Neighbor", tags: ["test"]}]} =
               TraverseKnowledgeGraph.execute(workspace_id(), %{start_id: start_id},
                 erm_gateway: ErmGatewayMock
               )
    end
  end
end
