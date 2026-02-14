defmodule EntityRelationshipManager.Views.EntityJSONTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Views.EntityJSON
  alias EntityRelationshipManager.UseCaseFixtures

  describe "render/2 show.json" do
    test "renders a single entity" do
      entity = UseCaseFixtures.entity()

      result = EntityJSON.render("show.json", %{entity: entity})

      assert result == %{
               data: %{
                 id: entity.id,
                 workspace_id: entity.workspace_id,
                 type: entity.type,
                 properties: entity.properties,
                 created_at: entity.created_at,
                 updated_at: entity.updated_at,
                 deleted_at: entity.deleted_at
               }
             }
    end
  end

  describe "render/2 index.json" do
    test "renders a list of entities" do
      entity1 = UseCaseFixtures.entity()
      entity2 = UseCaseFixtures.entity(%{id: UseCaseFixtures.valid_uuid2(), type: "Company"})

      result = EntityJSON.render("index.json", %{entities: [entity1, entity2]})

      assert %{data: data} = result
      assert length(data) == 2
      assert Enum.at(data, 0).id == entity1.id
      assert Enum.at(data, 1).id == entity2.id
    end
  end

  describe "render/2 delete.json" do
    test "renders a deleted entity with edge count" do
      entity = UseCaseFixtures.entity()

      result = EntityJSON.render("delete.json", %{entity: entity, deleted_edge_count: 3})

      assert result == %{
               data: %{
                 id: entity.id,
                 workspace_id: entity.workspace_id,
                 type: entity.type,
                 properties: entity.properties,
                 created_at: entity.created_at,
                 updated_at: entity.updated_at,
                 deleted_at: entity.deleted_at
               },
               meta: %{deleted_edge_count: 3}
             }
    end
  end

  describe "render/2 bulk.json" do
    test "renders bulk create result" do
      entity = UseCaseFixtures.entity()

      result = EntityJSON.render("bulk.json", %{entities: [entity], errors: []})

      assert %{data: data, errors: []} = result
      assert length(data) == 1
    end

    test "renders bulk result with errors" do
      entity = UseCaseFixtures.entity()
      errors = [%{index: 1, reason: :invalid_type}]

      result = EntityJSON.render("bulk.json", %{entities: [entity], errors: errors})

      assert %{data: data, errors: ^errors} = result
      assert length(data) == 1
    end
  end

  describe "render/2 bulk_delete.json" do
    test "renders bulk delete result" do
      result = EntityJSON.render("bulk_delete.json", %{deleted_count: 5, errors: []})

      assert result == %{
               data: %{deleted_count: 5},
               errors: []
             }
    end
  end
end
