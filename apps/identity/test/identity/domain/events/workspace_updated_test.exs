defmodule Identity.Domain.Events.WorkspaceUpdatedTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Events.WorkspaceUpdated

  @valid_attrs %{
    aggregate_id: "ws-123",
    actor_id: "system",
    workspace_id: "ws-123",
    name: "New Name"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert WorkspaceUpdated.event_type() == "identity.workspace_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert WorkspaceUpdated.aggregate_type() == "workspace"
    end
  end

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event = WorkspaceUpdated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "identity.workspace_updated"
      assert event.aggregate_type == "workspace"
      assert event.aggregate_id == "ws-123"
      assert event.actor_id == "system"
      assert event.metadata == %{}
    end

    test "sets all custom fields correctly" do
      event = WorkspaceUpdated.new(@valid_attrs)

      assert event.workspace_id == "ws-123"
      assert event.name == "New Name"
    end

    test "generates unique event_id for each call" do
      event1 = WorkspaceUpdated.new(@valid_attrs)
      event2 = WorkspaceUpdated.new(@valid_attrs)

      assert event1.event_id != event2.event_id
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceUpdated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when workspace_id is missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceUpdated.new(%{
          aggregate_id: "123",
          actor_id: "123",
          name: "Test"
        })
      end
    end

    test "allows custom metadata" do
      event = WorkspaceUpdated.new(Map.put(@valid_attrs, :metadata, %{source: "api"}))

      assert event.metadata == %{source: "api"}
    end
  end
end
