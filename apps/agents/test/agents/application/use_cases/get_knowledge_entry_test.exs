defmodule Agents.Application.UseCases.GetKnowledgeEntryTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.UseCases.GetKnowledgeEntry
  alias Agents.Domain.Entities.{KnowledgeEntry, KnowledgeRelationship}
  alias Agents.Mocks.ErmGatewayMock

  import Agents.Test.KnowledgeFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns {:ok, %{entry: knowledge_entry, relationships: [...]}} for existing entry" do
      entity_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})
      neighbor1 = erm_knowledge_entity(%{id: unique_id()})
      neighbor2 = erm_knowledge_entity(%{id: unique_id()})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, eid ->
        assert eid == entity_id
        {:ok, entity}
      end)
      |> expect(:get_neighbors, fn _ws_id, eid, _opts ->
        assert eid == entity_id
        {:ok, [neighbor1, neighbor2]}
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

    test "derives relationships from neighbors with correct from/to IDs" do
      entity_id = unique_id()
      other_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})
      neighbor = erm_knowledge_entity(%{id: other_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, entity} end)
      |> expect(:get_neighbors, fn _ws_id, _eid, _opts -> {:ok, [neighbor]} end)

      assert {:ok, %{entry: %KnowledgeEntry{}, relationships: [rel]}} =
               GetKnowledgeEntry.execute(workspace_id(), entity_id, erm_gateway: ErmGatewayMock)

      assert rel.from_id == entity_id
      assert rel.to_id == other_id
      assert rel.type == "relates_to"
    end

    test "returns empty relationships when no neighbors exist" do
      entity_id = unique_id()
      entity = erm_knowledge_entity(%{id: entity_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, entity} end)
      |> expect(:get_neighbors, fn _ws_id, _eid, _opts -> {:ok, []} end)

      assert {:ok, %{entry: %KnowledgeEntry{}, relationships: []}} =
               GetKnowledgeEntry.execute(workspace_id(), entity_id, erm_gateway: ErmGatewayMock)
    end
  end
end
