defmodule EntityRelationshipManager.Domain.Events.EntityDeletedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.EntityDeleted

  @valid_attrs %{
    aggregate_id: "ent-123",
    actor_id: "user-123",
    entity_id: "ent-123",
    workspace_id: "ws-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert EntityDeleted.event_type() == "entity_relationship_manager.entity_deleted"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert EntityDeleted.aggregate_type() == "entity"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = EntityDeleted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.entity_deleted"
      assert event.entity_id == "ent-123"
      assert event.workspace_id == "ws-123"
    end

    test "optional user_id defaults to nil" do
      event = EntityDeleted.new(@valid_attrs)
      assert event.user_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        EntityDeleted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
