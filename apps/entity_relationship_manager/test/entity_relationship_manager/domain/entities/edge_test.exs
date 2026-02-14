defmodule EntityRelationshipManager.Domain.Entities.EdgeTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Entities.Edge

  describe "new/1" do
    test "creates an edge with all fields" do
      now = DateTime.utc_now()

      edge =
        Edge.new(%{
          id: "edge-1",
          workspace_id: "ws-1",
          type: "FOLLOWS",
          source_id: "entity-1",
          target_id: "entity-2",
          properties: %{"weight" => 0.8},
          created_at: now,
          updated_at: now
        })

      assert %Edge{} = edge
      assert edge.id == "edge-1"
      assert edge.workspace_id == "ws-1"
      assert edge.type == "FOLLOWS"
      assert edge.source_id == "entity-1"
      assert edge.target_id == "entity-2"
      assert edge.properties == %{"weight" => 0.8}
      assert edge.created_at == now
      assert edge.updated_at == now
      assert edge.deleted_at == nil
    end

    test "defaults properties to empty map" do
      edge = Edge.new(%{id: "e1", type: "FOLLOWS", source_id: "s1", target_id: "t1"})

      assert edge.properties == %{}
    end
  end

  describe "deleted?/1" do
    test "returns false when deleted_at is nil" do
      edge = Edge.new(%{id: "e1", type: "FOLLOWS"})

      refute Edge.deleted?(edge)
    end

    test "returns true when deleted_at is set" do
      edge = Edge.new(%{id: "e1", type: "FOLLOWS", deleted_at: DateTime.utc_now()})

      assert Edge.deleted?(edge)
    end
  end
end
