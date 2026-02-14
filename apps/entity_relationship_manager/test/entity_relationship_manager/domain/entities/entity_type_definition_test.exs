defmodule EntityRelationshipManager.Domain.Entities.EntityTypeDefinitionTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Entities.EntityTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  describe "new/1" do
    test "creates an entity type definition with name and properties" do
      props = [
        PropertyDefinition.new(%{name: "email", type: :string, required: true}),
        PropertyDefinition.new(%{name: "age", type: :integer})
      ]

      entity_type = EntityTypeDefinition.new(%{name: "User", properties: props})

      assert %EntityTypeDefinition{} = entity_type
      assert entity_type.name == "User"
      assert length(entity_type.properties) == 2
      assert Enum.all?(entity_type.properties, &match?(%PropertyDefinition{}, &1))
    end

    test "defaults properties to empty list" do
      entity_type = EntityTypeDefinition.new(%{name: "Empty"})

      assert entity_type.properties == []
    end
  end

  describe "from_map/1" do
    test "deserializes from string-keyed map with nested properties" do
      map = %{
        "name" => "User",
        "properties" => [
          %{"name" => "email", "type" => "string", "required" => true},
          %{"name" => "age", "type" => "integer"}
        ]
      }

      entity_type = EntityTypeDefinition.from_map(map)

      assert %EntityTypeDefinition{} = entity_type
      assert entity_type.name == "User"
      assert length(entity_type.properties) == 2

      [email_prop, age_prop] = entity_type.properties
      assert %PropertyDefinition{name: "email", type: :string, required: true} = email_prop
      assert %PropertyDefinition{name: "age", type: :integer, required: false} = age_prop
    end

    test "defaults properties to empty list when not present" do
      entity_type = EntityTypeDefinition.from_map(%{"name" => "Empty"})

      assert entity_type.properties == []
    end
  end
end
