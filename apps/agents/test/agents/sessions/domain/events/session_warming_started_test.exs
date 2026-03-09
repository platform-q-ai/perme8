defmodule Agents.Sessions.Domain.Events.SessionWarmingStartedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionWarmingStarted

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    container_id: "container-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionWarmingStarted.event_type() == "sessions.session_warming_started"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionWarmingStarted.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionWarmingStarted.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.container_id == "container-123"
      assert event.event_type == "sessions.session_warming_started"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionWarmingStarted.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
