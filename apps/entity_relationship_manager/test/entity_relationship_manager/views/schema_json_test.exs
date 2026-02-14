defmodule EntityRelationshipManager.Views.SchemaJSONTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Views.SchemaJSON
  alias EntityRelationshipManager.UseCaseFixtures

  describe "render/2 show.json" do
    test "renders a schema definition with serialized types" do
      schema = UseCaseFixtures.schema_definition()

      result = SchemaJSON.render("show.json", %{schema: schema})

      assert %{data: data} = result
      assert data.id == schema.id
      assert data.workspace_id == schema.workspace_id
      assert data.version == schema.version
      assert length(data.entity_types) == 2
      assert length(data.edge_types) == 1

      [person, company] = data.entity_types
      assert person.name == "Person"
      assert length(person.properties) == 2
      assert Enum.at(person.properties, 0).name == "name"
      assert Enum.at(person.properties, 0).type == :string
      assert Enum.at(person.properties, 0).required == true

      assert company.name == "Company"

      [works_at] = data.edge_types
      assert works_at.name == "WORKS_AT"
    end
  end
end
