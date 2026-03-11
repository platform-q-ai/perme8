defmodule Agents.Sessions.Domain.Events.SessionMessageUpdatedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionMessageUpdated

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    message_count: 5,
    streaming_active: true,
    active_tool_calls: 2
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionMessageUpdated.event_type() == "sessions.session_message_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionMessageUpdated.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionMessageUpdated.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.message_count == 5
      assert event.streaming_active == true
      assert event.active_tool_calls == 2
      assert event.event_type == "sessions.session_message_updated"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionMessageUpdated.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
