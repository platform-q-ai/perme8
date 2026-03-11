defmodule Agents.Sessions.Domain.Events.SessionErrorOccurredTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionErrorOccurred

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    error_message: "boom",
    error_category: :auth,
    recoverable: false
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionErrorOccurred.event_type() == "sessions.session_error_occurred"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionErrorOccurred.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionErrorOccurred.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.error_message == "boom"
      assert event.error_category == :auth
      assert event.recoverable == false
      assert event.event_type == "sessions.session_error_occurred"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionErrorOccurred.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
