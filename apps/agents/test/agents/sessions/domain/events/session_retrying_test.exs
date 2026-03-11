defmodule Agents.Sessions.Domain.Events.SessionRetryingTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionRetrying

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    attempt: 2,
    message: "retrying soon",
    next_at: ~U[2026-03-10 12:00:00Z]
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionRetrying.event_type() == "sessions.session_retrying"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionRetrying.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionRetrying.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.attempt == 2
      assert event.message == "retrying soon"
      assert event.next_at == ~U[2026-03-10 12:00:00Z]
      assert event.event_type == "sessions.session_retrying"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionRetrying.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
