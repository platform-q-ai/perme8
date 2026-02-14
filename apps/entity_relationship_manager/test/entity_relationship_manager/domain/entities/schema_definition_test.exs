defmodule EntityRelationshipManager.Domain.Entities.SchemaDefinitionTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition
  alias EntityRelationshipManager.Domain.Entities.EntityTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  defp build_schema do
    entity_types = [
      EntityTypeDefinition.new(%{
        name: "User",
        properties: [
          PropertyDefinition.new(%{name: "email", type: :string, required: true})
        ]
      }),
      EntityTypeDefinition.new(%{
        name: "Post",
        properties: [
          PropertyDefinition.new(%{name: "title", type: :string, required: true})
        ]
      })
    ]

    edge_types = [
      EdgeTypeDefinition.new(%{
        name: "AUTHORED",
        properties: [
          PropertyDefinition.new(%{name: "created_at", type: :datetime})
        ]
      }),
      EdgeTypeDefinition.new(%{name: "FOLLOWS"})
    ]

    SchemaDefinition.new(%{
      id: "schema-1",
      workspace_id: "ws-1",
      entity_types: entity_types,
      edge_types: edge_types,
      version: 1
    })
  end

  describe "new/1" do
    test "creates a schema definition with all fields" do
      schema = build_schema()

      assert %SchemaDefinition{} = schema
      assert schema.id == "schema-1"
      assert schema.workspace_id == "ws-1"
      assert length(schema.entity_types) == 2
      assert length(schema.edge_types) == 2
      assert schema.version == 1
    end

    test "defaults entity_types and edge_types to empty lists" do
      schema = SchemaDefinition.new(%{id: "s1", workspace_id: "ws-1"})

      assert schema.entity_types == []
      assert schema.edge_types == []
    end
  end

  describe "get_entity_type/2" do
    test "returns entity type by name" do
      schema = build_schema()

      assert {:ok, entity_type} = SchemaDefinition.get_entity_type(schema, "User")
      assert entity_type.name == "User"
    end

    test "returns error for unknown entity type" do
      schema = build_schema()

      assert {:error, :not_found} = SchemaDefinition.get_entity_type(schema, "Unknown")
    end
  end

  describe "get_edge_type/2" do
    test "returns edge type by name" do
      schema = build_schema()

      assert {:ok, edge_type} = SchemaDefinition.get_edge_type(schema, "AUTHORED")
      assert edge_type.name == "AUTHORED"
    end

    test "returns error for unknown edge type" do
      schema = build_schema()

      assert {:error, :not_found} = SchemaDefinition.get_edge_type(schema, "UNKNOWN")
    end
  end

  describe "has_entity_type?/2" do
    test "returns true when entity type exists" do
      schema = build_schema()

      assert SchemaDefinition.has_entity_type?(schema, "User")
      assert SchemaDefinition.has_entity_type?(schema, "Post")
    end

    test "returns false when entity type does not exist" do
      schema = build_schema()

      refute SchemaDefinition.has_entity_type?(schema, "Unknown")
    end
  end

  describe "has_edge_type?/2" do
    test "returns true when edge type exists" do
      schema = build_schema()

      assert SchemaDefinition.has_edge_type?(schema, "AUTHORED")
      assert SchemaDefinition.has_edge_type?(schema, "FOLLOWS")
    end

    test "returns false when edge type does not exist" do
      schema = build_schema()

      refute SchemaDefinition.has_edge_type?(schema, "UNKNOWN")
    end
  end
end
