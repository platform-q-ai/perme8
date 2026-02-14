defmodule EntityRelationshipManager.Domain.Policies.SchemaValidationPolicyTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Policies.SchemaValidationPolicy
  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition
  alias EntityRelationshipManager.Domain.Entities.EntityTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition
  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Entities.Edge

  defp valid_schema do
    SchemaDefinition.new(%{
      id: "s1",
      workspace_id: "ws-1",
      entity_types: [
        EntityTypeDefinition.new(%{
          name: "User",
          properties: [
            PropertyDefinition.new(%{name: "email", type: :string, required: true}),
            PropertyDefinition.new(%{name: "age", type: :integer})
          ]
        }),
        EntityTypeDefinition.new(%{
          name: "Post",
          properties: [
            PropertyDefinition.new(%{name: "title", type: :string, required: true})
          ]
        })
      ],
      edge_types: [
        EdgeTypeDefinition.new(%{
          name: "AUTHORED",
          properties: [
            PropertyDefinition.new(%{name: "created_at", type: :datetime})
          ]
        }),
        EdgeTypeDefinition.new(%{name: "FOLLOWS"})
      ]
    })
  end

  describe "validate_schema_structure/1" do
    test "returns :ok for a valid schema" do
      assert :ok = SchemaValidationPolicy.validate_schema_structure(valid_schema())
    end

    test "rejects duplicate entity type names" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          entity_types: [
            EntityTypeDefinition.new(%{name: "User"}),
            EntityTypeDefinition.new(%{name: "User"})
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "duplicate entity type"))
    end

    test "rejects duplicate edge type names" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          edge_types: [
            EdgeTypeDefinition.new(%{name: "FOLLOWS"}),
            EdgeTypeDefinition.new(%{name: "FOLLOWS"})
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "duplicate edge type"))
    end

    test "rejects invalid entity type names" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          entity_types: [
            EntityTypeDefinition.new(%{name: "invalid name!!"})
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "invalid type name"))
    end

    test "rejects empty entity type names" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          entity_types: [
            EntityTypeDefinition.new(%{name: ""})
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "invalid type name"))
    end

    test "rejects invalid edge type names" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          edge_types: [
            EdgeTypeDefinition.new(%{name: "has spaces"})
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "invalid type name"))
    end

    test "rejects duplicate property names within an entity type" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          entity_types: [
            EntityTypeDefinition.new(%{
              name: "User",
              properties: [
                PropertyDefinition.new(%{name: "email", type: :string}),
                PropertyDefinition.new(%{name: "email", type: :integer})
              ]
            })
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "duplicate property"))
    end

    test "rejects invalid property types" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          entity_types: [
            EntityTypeDefinition.new(%{
              name: "User",
              properties: [
                PropertyDefinition.new(%{name: "data", type: :binary})
              ]
            })
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert Enum.any?(errors, &String.contains?(&1, "invalid property type"))
    end

    test "collects multiple errors" do
      schema =
        SchemaDefinition.new(%{
          id: "s1",
          workspace_id: "ws-1",
          entity_types: [
            EntityTypeDefinition.new(%{name: "User"}),
            EntityTypeDefinition.new(%{name: "User"}),
            EntityTypeDefinition.new(%{name: "bad name!!"})
          ]
        })

      assert {:error, errors} = SchemaValidationPolicy.validate_schema_structure(schema)
      assert length(errors) >= 2
    end
  end

  describe "validate_entity_against_schema/3" do
    test "returns :ok for a valid entity" do
      schema = valid_schema()

      entity =
        Entity.new(%{
          id: "e1",
          workspace_id: "ws-1",
          type: "User",
          properties: %{"email" => "test@example.com", "age" => 25}
        })

      assert :ok = SchemaValidationPolicy.validate_entity_against_schema(entity, schema, "User")
    end

    test "returns error when entity type not in schema" do
      schema = valid_schema()

      entity =
        Entity.new(%{
          id: "e1",
          workspace_id: "ws-1",
          type: "Unknown",
          properties: %{}
        })

      assert {:error, reason} =
               SchemaValidationPolicy.validate_entity_against_schema(entity, schema, "Unknown")

      assert String.contains?(reason, "not defined")
    end

    test "returns error when entity properties fail validation" do
      schema = valid_schema()

      entity =
        Entity.new(%{
          id: "e1",
          workspace_id: "ws-1",
          type: "User",
          properties: %{}
        })

      assert {:error, _errors} =
               SchemaValidationPolicy.validate_entity_against_schema(entity, schema, "User")
    end
  end

  describe "validate_edge_against_schema/3" do
    test "returns :ok for a valid edge" do
      schema = valid_schema()

      edge =
        Edge.new(%{
          id: "edge-1",
          workspace_id: "ws-1",
          type: "AUTHORED",
          source_id: "e1",
          target_id: "e2",
          properties: %{"created_at" => "2024-01-15T10:30:00Z"}
        })

      assert :ok = SchemaValidationPolicy.validate_edge_against_schema(edge, schema, "AUTHORED")
    end

    test "returns error when edge type not in schema" do
      schema = valid_schema()

      edge =
        Edge.new(%{
          id: "edge-1",
          workspace_id: "ws-1",
          type: "UNKNOWN",
          source_id: "e1",
          target_id: "e2"
        })

      assert {:error, reason} =
               SchemaValidationPolicy.validate_edge_against_schema(edge, schema, "UNKNOWN")

      assert String.contains?(reason, "not defined")
    end

    test "returns :ok for edge type with no properties defined" do
      schema = valid_schema()

      edge =
        Edge.new(%{
          id: "edge-1",
          workspace_id: "ws-1",
          type: "FOLLOWS",
          source_id: "e1",
          target_id: "e2"
        })

      assert :ok = SchemaValidationPolicy.validate_edge_against_schema(edge, schema, "FOLLOWS")
    end
  end
end
