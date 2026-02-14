defmodule EntityRelationshipManager.Domain.Entities.PropertyDefinitionTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  describe "new/1" do
    test "creates a property definition with all fields" do
      prop =
        PropertyDefinition.new(%{
          name: "email",
          type: :string,
          required: true,
          constraints: %{max_length: 255}
        })

      assert %PropertyDefinition{} = prop
      assert prop.name == "email"
      assert prop.type == :string
      assert prop.required == true
      assert prop.constraints == %{max_length: 255}
    end

    test "defaults required to false" do
      prop = PropertyDefinition.new(%{name: "age", type: :integer})

      assert prop.required == false
    end

    test "defaults constraints to empty map" do
      prop = PropertyDefinition.new(%{name: "age", type: :integer})

      assert prop.constraints == %{}
    end

    test "accepts all valid types" do
      for type <- [:string, :integer, :float, :boolean, :datetime] do
        prop = PropertyDefinition.new(%{name: "field", type: type})
        assert prop.type == type
      end
    end
  end

  describe "from_map/1" do
    test "deserializes from string-keyed map" do
      prop =
        PropertyDefinition.from_map(%{
          "name" => "email",
          "type" => "string",
          "required" => true,
          "constraints" => %{"max_length" => 255}
        })

      assert %PropertyDefinition{} = prop
      assert prop.name == "email"
      assert prop.type == :string
      assert prop.required == true
      assert prop.constraints == %{"max_length" => 255}
    end

    test "defaults required to false when not present in map" do
      prop = PropertyDefinition.from_map(%{"name" => "age", "type" => "integer"})

      assert prop.required == false
    end

    test "defaults constraints to empty map when not present" do
      prop = PropertyDefinition.from_map(%{"name" => "age", "type" => "integer"})

      assert prop.constraints == %{}
    end

    test "converts string type to atom" do
      for {str, atom} <- [
            {"string", :string},
            {"integer", :integer},
            {"float", :float},
            {"boolean", :boolean},
            {"datetime", :datetime}
          ] do
        prop = PropertyDefinition.from_map(%{"name" => "field", "type" => str})
        assert prop.type == atom
      end
    end
  end
end
