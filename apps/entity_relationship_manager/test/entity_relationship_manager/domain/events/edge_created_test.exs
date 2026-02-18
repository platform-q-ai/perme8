defmodule EntityRelationshipManager.Domain.Events.EdgeCreatedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.EdgeCreated

  @valid_attrs %{
    aggregate_id: "edge-123",
    actor_id: "user-123",
    edge_id: "edge-123",
    workspace_id: "ws-123",
    source_id: "ent-1",
    target_id: "ent-2",
    edge_type: "knows"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert EdgeCreated.event_type() == "entity_relationship_manager.edge_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert EdgeCreated.aggregate_type() == "edge"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = EdgeCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.edge_created"
      assert event.aggregate_type == "edge"
      assert event.edge_id == "edge-123"
      assert event.workspace_id == "ws-123"
      assert event.source_id == "ent-1"
      assert event.target_id == "ent-2"
      assert event.edge_type == "knows"
    end

    test "optional user_id defaults to nil" do
      event = EdgeCreated.new(@valid_attrs)
      assert event.user_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        EdgeCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
