defmodule EntityRelationshipManager.Domain.Entities.EntityTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Entities.Entity

  describe "new/1" do
    test "creates an entity with all fields" do
      now = DateTime.utc_now()

      entity =
        Entity.new(%{
          id: "entity-1",
          workspace_id: "ws-1",
          type: "User",
          properties: %{"email" => "test@example.com", "age" => 30},
          created_at: now,
          updated_at: now
        })

      assert %Entity{} = entity
      assert entity.id == "entity-1"
      assert entity.workspace_id == "ws-1"
      assert entity.type == "User"
      assert entity.properties == %{"email" => "test@example.com", "age" => 30}
      assert entity.created_at == now
      assert entity.updated_at == now
      assert entity.deleted_at == nil
    end

    test "defaults properties to empty map" do
      entity = Entity.new(%{id: "e1", type: "User"})

      assert entity.properties == %{}
    end
  end

  describe "deleted?/1" do
    test "returns false when deleted_at is nil" do
      entity = Entity.new(%{id: "e1", type: "User"})

      refute Entity.deleted?(entity)
    end

    test "returns true when deleted_at is set" do
      entity = Entity.new(%{id: "e1", type: "User", deleted_at: DateTime.utc_now()})

      assert Entity.deleted?(entity)
    end
  end
end
