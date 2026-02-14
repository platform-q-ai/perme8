defmodule EntityRelationshipManager.Views.TraversalJSONTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Views.TraversalJSON
  alias EntityRelationshipManager.UseCaseFixtures

  describe "render/2 neighbors.json" do
    test "renders neighbor entities" do
      entity = UseCaseFixtures.entity()

      result = TraversalJSON.render("neighbors.json", %{entities: [entity]})

      assert %{data: [data]} = result
      assert data.id == entity.id
    end
  end

  describe "render/2 paths.json" do
    test "renders paths between entities" do
      paths = [["id-1", "id-2", "id-3"], ["id-1", "id-4", "id-3"]]

      result = TraversalJSON.render("paths.json", %{paths: paths})

      assert result == %{data: paths}
    end
  end

  describe "render/2 traverse.json" do
    test "renders traversal result entities" do
      entity = UseCaseFixtures.entity()

      result = TraversalJSON.render("traverse.json", %{entities: [entity]})

      assert %{data: [data]} = result
      assert data.id == entity.id
    end
  end
end
