defmodule Agents.Sessions.Domain.Events.TaskFailedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.TaskFailed

  @valid_attrs %{
    aggregate_id: "task-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    target_user_id: "user-123",
    instruction: "Implement a feature",
    error: "Container start failed"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TaskFailed.event_type() == "sessions.task_failed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TaskFailed.aggregate_type() == "task"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TaskFailed.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.task_failed"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.target_user_id == "user-123"
      assert event.instruction == "Implement a feature"
      assert event.error == "Container start failed"
    end

    test "auto-generates event_id and occurred_at" do
      event = TaskFailed.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end

    test "error field is optional and defaults to nil" do
      event =
        TaskFailed.new(%{
          aggregate_id: "task-123",
          actor_id: "user-123",
          task_id: "task-123",
          user_id: "user-123",
          target_user_id: "user-123"
        })

      assert event.error == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TaskFailed.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
