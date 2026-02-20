defmodule Agents.Sessions.Domain.Events.TaskCreatedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.TaskCreated

  @valid_attrs %{
    aggregate_id: "task-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    instruction: "Write tests for the login flow"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TaskCreated.event_type() == "sessions.task_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TaskCreated.aggregate_type() == "task"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TaskCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.task_created"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.instruction == "Write tests for the login flow"
    end

    test "workspace_id is optional and defaults to nil" do
      event = TaskCreated.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TaskCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
