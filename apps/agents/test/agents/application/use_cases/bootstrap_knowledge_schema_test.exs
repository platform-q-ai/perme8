defmodule Agents.Application.UseCases.BootstrapKnowledgeSchemaTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.UseCases.BootstrapKnowledgeSchema
  alias Agents.Mocks.ErmGatewayMock

  import Agents.Test.KnowledgeFixtures

  setup :verify_on_exit!

  describe "execute/2" do
    test "when schema already exists with KnowledgeEntry type, returns :already_bootstrapped" do
      schema = schema_definition_with_knowledge()

      ErmGatewayMock
      |> expect(:get_schema, fn ws_id ->
        assert ws_id == workspace_id()
        {:ok, schema}
      end)

      assert {:ok, :already_bootstrapped} =
               BootstrapKnowledgeSchema.execute(workspace_id(), erm_gateway: ErmGatewayMock)
    end

    test "when schema exists but missing KnowledgeEntry type, upserts schema" do
      alias EntityRelationshipManager.Domain.Entities.SchemaDefinition

      schema =
        SchemaDefinition.new(%{
          id: "schema-001",
          workspace_id: workspace_id(),
          version: 1,
          entity_types: [],
          edge_types: []
        })

      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)
      |> expect(:upsert_schema, fn ws_id, attrs ->
        assert ws_id == workspace_id()
        entity_types = attrs[:entity_types] || attrs["entity_types"]

        assert Enum.any?(entity_types, fn et ->
                 et.name == "KnowledgeEntry" || et["name"] == "KnowledgeEntry"
               end)

        {:ok, schema_definition_with_knowledge()}
      end)

      assert {:ok, _schema} =
               BootstrapKnowledgeSchema.execute(workspace_id(), erm_gateway: ErmGatewayMock)
    end

    test "when no schema exists, creates full schema with entity and edge types" do
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)
      |> expect(:upsert_schema, fn ws_id, attrs ->
        assert ws_id == workspace_id()

        entity_types = attrs[:entity_types] || attrs["entity_types"]

        assert Enum.any?(entity_types, fn et ->
                 et.name == "KnowledgeEntry" || et["name"] == "KnowledgeEntry"
               end)

        edge_types = attrs[:edge_types] || attrs["edge_types"]
        edge_type_names = Enum.map(edge_types, fn et -> et.name || et["name"] end)
        assert "relates_to" in edge_type_names
        assert "depends_on" in edge_type_names
        assert "prerequisite_for" in edge_type_names
        assert "example_of" in edge_type_names
        assert "part_of" in edge_type_names
        assert "supersedes" in edge_type_names

        {:ok, schema_definition_with_knowledge()}
      end)

      assert {:ok, _schema} =
               BootstrapKnowledgeSchema.execute(workspace_id(), erm_gateway: ErmGatewayMock)
    end

    test "schema includes KnowledgeEntry entity type with correct properties" do
      ErmGatewayMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)
      |> expect(:upsert_schema, fn _ws_id, attrs ->
        entity_types = attrs[:entity_types] || attrs["entity_types"]
        knowledge_type = Enum.find(entity_types, fn et -> et.name == "KnowledgeEntry" end)
        assert knowledge_type != nil

        prop_names = Enum.map(knowledge_type.properties, & &1.name)
        assert "title" in prop_names
        assert "body" in prop_names
        assert "category" in prop_names
        assert "tags" in prop_names
        assert "code_snippets" in prop_names
        assert "file_paths" in prop_names
        assert "external_links" in prop_names
        assert "last_verified_at" in prop_names

        {:ok, schema_definition_with_knowledge()}
      end)

      assert {:ok, _} =
               BootstrapKnowledgeSchema.execute(workspace_id(), erm_gateway: ErmGatewayMock)
    end

    test "is idempotent -- calling twice does not error" do
      schema = schema_definition_with_knowledge()

      ErmGatewayMock
      |> expect(:get_schema, 2, fn _ws_id -> {:ok, schema} end)

      assert {:ok, :already_bootstrapped} =
               BootstrapKnowledgeSchema.execute(workspace_id(), erm_gateway: ErmGatewayMock)

      assert {:ok, :already_bootstrapped} =
               BootstrapKnowledgeSchema.execute(workspace_id(), erm_gateway: ErmGatewayMock)
    end
  end
end
