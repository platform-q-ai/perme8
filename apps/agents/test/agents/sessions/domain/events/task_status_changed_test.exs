defmodule Agents.Sessions.Domain.Events.TaskStatusChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.TaskStatusChanged

  @valid_attrs %{
    aggregate_id: "task-123",
    actor_id: "system",
    task_id: "task-123",
    old_status: "pending",
    new_status: "starting"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TaskStatusChanged.event_type() == "sessions.task_status_changed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TaskStatusChanged.aggregate_type() == "task"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TaskStatusChanged.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.task_status_changed"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.old_status == "pending"
      assert event.new_status == "starting"
    end

    test "workspace_id is optional and defaults to nil" do
      event = TaskStatusChanged.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TaskStatusChanged.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
