defmodule EntityRelationshipManager.Views.EdgeJSONTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Views.EdgeJSON
  alias EntityRelationshipManager.UseCaseFixtures

  describe "render/2 show.json" do
    test "renders a single edge" do
      edge = UseCaseFixtures.edge()

      result = EdgeJSON.render("show.json", %{edge: edge})

      assert result == %{
               data: %{
                 id: edge.id,
                 workspace_id: edge.workspace_id,
                 type: edge.type,
                 source_id: edge.source_id,
                 target_id: edge.target_id,
                 properties: edge.properties,
                 created_at: edge.created_at,
                 updated_at: edge.updated_at,
                 deleted_at: edge.deleted_at
               }
             }
    end
  end

  describe "render/2 index.json" do
    test "renders a list of edges" do
      edge = UseCaseFixtures.edge()

      result = EdgeJSON.render("index.json", %{edges: [edge]})

      assert %{data: [data]} = result
      assert data.id == edge.id
      assert data.source_id == edge.source_id
      assert data.target_id == edge.target_id
    end
  end

  describe "render/2 bulk.json" do
    test "renders bulk create result" do
      edge = UseCaseFixtures.edge()

      result = EdgeJSON.render("bulk.json", %{edges: [edge], errors: []})

      assert %{data: data, errors: []} = result
      assert length(data) == 1
    end
  end
end
