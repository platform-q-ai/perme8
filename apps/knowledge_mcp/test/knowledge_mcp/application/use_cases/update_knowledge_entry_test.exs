defmodule KnowledgeMcp.Application.UseCases.UpdateKnowledgeEntryTest do
  use ExUnit.Case, async: true

  import Mox

  alias KnowledgeMcp.Application.UseCases.UpdateKnowledgeEntry
  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry
  alias KnowledgeMcp.Mocks.ErmGatewayMock

  import KnowledgeMcp.Test.Fixtures

  setup :verify_on_exit!

  describe "execute/4" do
    test "updates entry with valid partial attrs, returns {:ok, knowledge_entry}" do
      entity_id = unique_id()
      existing = erm_knowledge_entity(%{id: entity_id})

      updated =
        erm_knowledge_entity(%{
          id: entity_id,
          properties: Map.merge(existing.properties, %{"title" => "Updated Title"})
        })

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, eid ->
        assert eid == entity_id
        {:ok, existing}
      end)
      |> expect(:update_entity, fn _ws_id, eid, attrs ->
        assert eid == entity_id
        assert attrs.properties["title"] == "Updated Title"
        {:ok, updated}
      end)

      assert {:ok, %KnowledgeEntry{title: "Updated Title"}} =
               UpdateKnowledgeEntry.execute(workspace_id(), entity_id, %{title: "Updated Title"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :not_found} when entry doesn't exist" do
      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:error, :not_found} end)

      assert {:error, :not_found} =
               UpdateKnowledgeEntry.execute(workspace_id(), "nonexistent", %{title: "New"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "returns {:error, :invalid_category} if category provided but invalid" do
      assert {:error, :invalid_category} =
               UpdateKnowledgeEntry.execute(workspace_id(), unique_id(), %{category: "wrong"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "merges update properties with existing entity properties" do
      entity_id = unique_id()

      existing =
        erm_knowledge_entity(%{
          id: entity_id,
          properties: %{
            "title" => "Original",
            "body" => "Original body",
            "category" => "how_to",
            "tags" => Jason.encode!(["old"]),
            "code_snippets" => Jason.encode!([]),
            "file_paths" => Jason.encode!([]),
            "external_links" => Jason.encode!([]),
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, existing} end)
      |> expect(:update_entity, fn _ws_id, _eid, attrs ->
        # Original body should be preserved; title updated
        assert attrs.properties["title"] == "New Title"
        assert attrs.properties["body"] == "Original body"
        {:ok, erm_knowledge_entity(%{id: entity_id, properties: attrs.properties})}
      end)

      assert {:ok, %KnowledgeEntry{}} =
               UpdateKnowledgeEntry.execute(workspace_id(), entity_id, %{title: "New Title"},
                 erm_gateway: ErmGatewayMock
               )
    end

    test "handles last_verified_at update" do
      entity_id = unique_id()
      existing = erm_knowledge_entity(%{id: entity_id})

      ErmGatewayMock
      |> expect(:get_entity, fn _ws_id, _eid -> {:ok, existing} end)
      |> expect(:update_entity, fn _ws_id, _eid, attrs ->
        assert attrs.properties["last_verified_at"] == "2026-02-15T00:00:00Z"
        {:ok, erm_knowledge_entity(%{id: entity_id, properties: attrs.properties})}
      end)

      assert {:ok, _} =
               UpdateKnowledgeEntry.execute(
                 workspace_id(),
                 entity_id,
                 %{last_verified_at: "2026-02-15T00:00:00Z"},
                 erm_gateway: ErmGatewayMock
               )
    end
  end
end
