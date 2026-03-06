defmodule Agents.Sessions.Domain.Events.TaskLaneChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.TaskLaneChanged

  @valid_attrs %{
    aggregate_id: "task-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    from_lane: :cold,
    to_lane: :processing
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TaskLaneChanged.event_type() == "sessions.task_lane_changed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TaskLaneChanged.aggregate_type() == "task"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TaskLaneChanged.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.task_lane_changed"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.from_lane == :cold
      assert event.to_lane == :processing
    end

    test "auto-generates event_id and occurred_at" do
      event = TaskLaneChanged.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TaskLaneChanged.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
