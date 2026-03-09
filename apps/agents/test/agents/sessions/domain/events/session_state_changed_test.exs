defmodule Agents.Sessions.Domain.Events.SessionStateChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionStateChanged

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    from_state: :queued_cold,
    to_state: :warming,
    lifecycle_state: :warming,
    container_id: "container-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionStateChanged.event_type() == "sessions.session_state_changed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionStateChanged.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionStateChanged.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.from_state == :queued_cold
      assert event.to_state == :warming
      assert event.lifecycle_state == :warming
      assert event.container_id == "container-123"
      assert event.event_type == "sessions.session_state_changed"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionStateChanged.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
