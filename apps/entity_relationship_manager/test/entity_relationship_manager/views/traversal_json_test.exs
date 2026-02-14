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
      entity1 = UseCaseFixtures.entity()
      entity2 = UseCaseFixtures.entity(%{id: UseCaseFixtures.valid_uuid2()})
      paths = [%{nodes: [entity1, entity2], edges: []}]

      result = TraversalJSON.render("paths.json", %{paths: paths})

      assert %{data: [path]} = result
      assert length(path.nodes) == 2
      assert length(path.edges) == 0
    end
  end

  describe "render/2 traverse.json" do
    test "renders traversal result entities" do
      entity = UseCaseFixtures.entity()
      meta = %{depth: 1}

      result = TraversalJSON.render("traverse.json", %{entities: [entity], meta: meta})

      assert %{data: %{nodes: nodes, edges: _}, meta: ^meta} = result
      assert length(nodes) == 1
      assert Enum.at(nodes, 0).id == entity.id
    end
  end
end
