defmodule Agents.Sessions.Domain.Events.TaskCancelledTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.TaskCancelled

  @valid_attrs %{
    aggregate_id: "task-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    target_user_id: "user-123",
    instruction: "Implement a feature"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TaskCancelled.event_type() == "sessions.task_cancelled"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TaskCancelled.aggregate_type() == "task"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TaskCancelled.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.task_cancelled"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.target_user_id == "user-123"
      assert event.instruction == "Implement a feature"
    end

    test "auto-generates event_id and occurred_at" do
      event = TaskCancelled.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TaskCancelled.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
