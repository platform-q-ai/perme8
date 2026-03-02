defmodule Agents.Sessions.Domain.Events.TaskPromotedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.TaskPromoted

  @valid_attrs %{
    aggregate_id: "task-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert TaskPromoted.event_type() == "sessions.task_promoted"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert TaskPromoted.aggregate_type() == "task"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = TaskPromoted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.task_promoted"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
    end

    test "auto-generates event_id and occurred_at" do
      event = TaskPromoted.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        TaskPromoted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
