defmodule EntityRelationshipManager.Domain.Events.SchemaCreatedTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Events.SchemaCreated

  @valid_attrs %{
    aggregate_id: "schema-123",
    actor_id: "user-123",
    schema_id: "schema-123",
    workspace_id: "ws-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SchemaCreated.event_type() == "entity_relationship_manager.schema_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SchemaCreated.aggregate_type() == "schema"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = SchemaCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "entity_relationship_manager.schema_created"
      assert event.aggregate_type == "schema"
      assert event.schema_id == "schema-123"
      assert event.workspace_id == "ws-123"
    end

    test "optional user_id defaults to nil" do
      event = SchemaCreated.new(@valid_attrs)
      assert event.user_id == nil
    end

    test "optional name defaults to nil" do
      event = SchemaCreated.new(@valid_attrs)
      assert event.name == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        SchemaCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
