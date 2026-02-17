defmodule KnowledgeMcp.Application.UseCases.GetKnowledgeEntryTest do
  use ExUnit.Case, async: true

  import Mox

  alias KnowledgeMcp.Application.UseCases.GetKnowledgeEntry
  alias KnowledgeMcp.Domain.Entities.{KnowledgeEntry, KnowledgeRelationship}
  alias KnowledgeMcp.Mocks.ErmGatewayMock

  import KnowledgeMcp.Test.Fixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns {:ok, %{entry: knowledge_entry, relationships: [...]}} for existing entry" do
      entity_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})

      edge1 =
        erm_knowledge_edge(%{source_id: entity_id, target_id: unique_id(), type: "relates_to"})

      edge2 =
        erm_knowledge_edge(%{source_id: unique_id(), target_id: entity_id, type: "depends_on"})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, eid ->
        assert eid == entity_id
        {:ok, entity}
      end)
      |> expect(:list_edges, fn _ws_id, filters ->
        assert filters.entity_id == entity_id
        {:ok, [edge1, edge2]}
      end)

      assert {:ok, %{entry: %KnowledgeEntry{id: ^entity_id}, relationships: rels}} =
               GetKnowledgeEntry.execute(workspace_id(), entity_id, erm_gateway: ErmGatewayMock)

      assert length(rels) == 2
      assert Enum.all?(rels, &match?(%KnowledgeRelationship{}, &1))
    end

    test "returns {:error, :not_found} for non-existent entry" do
      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:error, :not_found} end)

      assert {:error, :not_found} =
               GetKnowledgeEntry.execute(workspace_id(), "nonexistent",
                 erm_gateway: ErmGatewayMock
               )
    end

    test "converts all ERM entities/edges to domain types" do
      entity_id = unique_id()
      other_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})

      edge =
        erm_knowledge_edge(%{
          source_id: entity_id,
          target_id: other_id,
          type: "prerequisite_for"
        })

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, entity} end)
      |> expect(:list_edges, fn _ws_id, _filters -> {:ok, [edge]} end)

      assert {:ok, %{entry: %KnowledgeEntry{}, relationships: [rel]}} =
               GetKnowledgeEntry.execute(workspace_id(), entity_id, erm_gateway: ErmGatewayMock)

      assert rel.from_id == entity_id
      assert rel.to_id == other_id
      assert rel.type == "prerequisite_for"
    end

    test "returns empty relationships when no edges exist" do
      entity_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, entity} end)
      |> expect(:list_edges, fn _ws_id, _filters -> {:ok, []} end)

      assert {:ok, %{entry: %KnowledgeEntry{}, relationships: []}} =
               GetKnowledgeEntry.execute(workspace_id(), entity_id, erm_gateway: ErmGatewayMock)
    end
  end
end
