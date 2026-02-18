defmodule EntityRelationshipManager.Domain.Events.EntityCreatedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.EntityCreated

  @valid_attrs %{
    aggregate_id: "ent-123",
    actor_id: "user-123",
    entity_id: "ent-123",
    workspace_id: "ws-123",
    entity_type: "person"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert EntityCreated.event_type() == "entity_relationship_manager.entity_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert EntityCreated.aggregate_type() == "entity"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = EntityCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.entity_created"
      assert event.aggregate_type == "entity"
      assert event.entity_id == "ent-123"
      assert event.workspace_id == "ws-123"
      assert event.entity_type == "person"
    end

    test "optional properties defaults to empty map" do
      event = EntityCreated.new(@valid_attrs)
      assert event.properties == %{}
    end

    test "optional user_id defaults to nil" do
      event = EntityCreated.new(@valid_attrs)
      assert event.user_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        EntityCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
