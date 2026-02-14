defmodule EntityRelationshipManager.Domain.Entities.EdgeTypeDefinitionTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  describe "new/1" do
    test "creates an edge type definition with name and properties" do
      props = [
        PropertyDefinition.new(%{name: "weight", type: :float}),
        PropertyDefinition.new(%{name: "since", type: :datetime})
      ]

      edge_type = EdgeTypeDefinition.new(%{name: "FOLLOWS", properties: props})

      assert %EdgeTypeDefinition{} = edge_type
      assert edge_type.name == "FOLLOWS"
      assert length(edge_type.properties) == 2
      assert Enum.all?(edge_type.properties, &match?(%PropertyDefinition{}, &1))
    end

    test "defaults properties to empty list" do
      edge_type = EdgeTypeDefinition.new(%{name: "KNOWS"})

      assert edge_type.properties == []
    end
  end

  describe "from_map/1" do
    test "deserializes from string-keyed map with nested properties" do
      map = %{
        "name" => "FOLLOWS",
        "properties" => [
          %{"name" => "weight", "type" => "float"},
          %{"name" => "since", "type" => "datetime", "required" => true}
        ]
      }

      edge_type = EdgeTypeDefinition.from_map(map)

      assert %EdgeTypeDefinition{} = edge_type
      assert edge_type.name == "FOLLOWS"
      assert length(edge_type.properties) == 2

      [weight_prop, since_prop] = edge_type.properties
      assert %PropertyDefinition{name: "weight", type: :float, required: false} = weight_prop
      assert %PropertyDefinition{name: "since", type: :datetime, required: true} = since_prop
    end

    test "defaults properties to empty list when not present" do
      edge_type = EdgeTypeDefinition.from_map(%{"name" => "KNOWS"})

      assert edge_type.properties == []
    end
  end
end
