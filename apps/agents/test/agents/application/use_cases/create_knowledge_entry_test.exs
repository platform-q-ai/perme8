defmodule Agents.Application.UseCases.CreateKnowledgeEntryTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.UseCases.CreateKnowledgeEntry
  alias Agents.Domain.Entities.KnowledgeEntry
  alias Agents.Mocks.ErmGatewayMock

  import Agents.Test.KnowledgeFixtures

  setup :verify_on_exit!

  defp setup_bootstrap_mock do
    ErmGatewayMock
    |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
  end

  describe "execute/3" do
    test "creates entry with valid attrs, returns {:ok, knowledge_entry}" do
      setup_bootstrap_mock()

      created_entity =
        erm_knowledge_entity(%{
          properties: %{
            "title" => "New Entry",
            "body" => "Content here",
            "category" => "how_to",
            "tags" => Jason.encode!(["tag1"]),
            "code_snippets" => Jason.encode!([]),
            "file_paths" => Jason.encode!([]),
            "external_links" => Jason.encode!([]),
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:create_entity, fn ws_id, attrs ->
        assert ws_id == workspace_id()
        assert attrs.type == "KnowledgeEntry"
        assert attrs.properties["title"] == "New Entry"
        {:ok, created_entity}
      end)

      attrs = valid_entry_attrs(%{title: "New Entry", body: "Content here", tags: ["tag1"]})

      assert {:ok, %KnowledgeEntry{} = entry} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)

      assert entry.title == "New Entry"
    end

    test "calls BootstrapKnowledgeSchema first" do
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition_with_knowledge()} end)
      |> expect(:create_entity, fn _ws_id, _attrs ->
        {:ok, erm_knowledge_entity()}
      end)

      attrs = valid_entry_attrs()

      assert {:ok, _} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end

    test "creates ERM entity with type KnowledgeEntry and JSON-encoded list properties" do
      setup_bootstrap_mock()

      ErmGatewayMock
      |> expect(:create_entity, fn _ws_id, attrs ->
        assert attrs.type == "KnowledgeEntry"
        assert is_binary(attrs.properties["tags"])
        assert Jason.decode!(attrs.properties["tags"]) == ["arch", "design"]
        {:ok, erm_knowledge_entity()}
      end)

      attrs = valid_entry_attrs(%{tags: ["arch", "design"]})

      assert {:ok, _} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end

    test "returns {:error, :title_required} for missing title" do
      attrs = %{body: "Content", category: "how_to"}

      assert {:error, :title_required} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end

    test "returns {:error, :body_required} for missing body" do
      attrs = %{title: "Title", category: "how_to"}

      assert {:error, :body_required} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end

    test "returns {:error, :invalid_category} for bad category" do
      attrs = %{title: "Title", body: "Content", category: "wrong"}

      assert {:error, :invalid_category} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end

    test "returns {:error, :too_many_tags} for > 20 tags" do
      tags = Enum.map(1..21, &"tag-#{&1}")
      attrs = valid_entry_attrs(%{tags: tags})

      assert {:error, :too_many_tags} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end

    test "converts ERM Entity response back to KnowledgeEntry domain entity" do
      setup_bootstrap_mock()

      entity =
        erm_knowledge_entity(%{
          id: "converted-id",
          properties: %{
            "title" => "Converted",
            "body" => "Body text",
            "category" => "concept",
            "tags" => Jason.encode!(["a", "b"]),
            "code_snippets" => Jason.encode!([]),
            "file_paths" => Jason.encode!([]),
            "external_links" => Jason.encode!([]),
            "last_verified_at" => nil
          }
        })

      ErmGatewayMock
      |> expect(:create_entity, fn _ws_id, _attrs -> {:ok, entity} end)

      attrs = valid_entry_attrs(%{title: "Converted", body: "Body text", category: "concept"})

      assert {:ok, %KnowledgeEntry{id: "converted-id", title: "Converted", tags: ["a", "b"]}} =
               CreateKnowledgeEntry.execute(workspace_id(), attrs, erm_gateway: ErmGatewayMock)
    end
  end
end
