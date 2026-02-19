defmodule EntityRelationshipManager.Domain.Events.SchemaUpdatedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.SchemaUpdated

  @valid_attrs %{
    aggregate_id: "schema-123",
    actor_id: "user-123",
    schema_id: "schema-123",
    workspace_id: "ws-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SchemaUpdated.event_type() == "entity_relationship_manager.schema_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SchemaUpdated.aggregate_type() == "schema"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = SchemaUpdated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.schema_updated"
      assert event.schema_id == "schema-123"
      assert event.workspace_id == "ws-123"
    end

    test "optional changes defaults to empty map" do
      event = SchemaUpdated.new(@valid_attrs)
      assert event.changes == %{}
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        SchemaUpdated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
