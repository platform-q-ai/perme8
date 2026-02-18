defmodule EntityRelationshipManager.Domain.Events.EdgeDeletedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.EdgeDeleted

  @valid_attrs %{
    aggregate_id: "edge-123",
    actor_id: "user-123",
    edge_id: "edge-123",
    workspace_id: "ws-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert EdgeDeleted.event_type() == "entity_relationship_manager.edge_deleted"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert EdgeDeleted.aggregate_type() == "edge"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = EdgeDeleted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.edge_deleted"
      assert event.aggregate_type == "edge"
      assert event.edge_id == "edge-123"
      assert event.workspace_id == "ws-123"
    end

    test "optional user_id defaults to nil" do
      event = EdgeDeleted.new(@valid_attrs)
      assert event.user_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        EdgeDeleted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
