defmodule EntityRelationshipManager.Domain.Events.EntityUpdatedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.EntityUpdated

  @valid_attrs %{
    aggregate_id: "ent-123",
    actor_id: "user-123",
    entity_id: "ent-123",
    workspace_id: "ws-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert EntityUpdated.event_type() == "entity_relationship_manager.entity_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert EntityUpdated.aggregate_type() == "entity"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = EntityUpdated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.entity_updated"
      assert event.entity_id == "ent-123"
      assert event.workspace_id == "ws-123"
    end

    test "optional changes defaults to empty map" do
      event = EntityUpdated.new(@valid_attrs)
      assert event.changes == %{}
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        EntityUpdated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
