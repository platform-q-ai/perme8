defmodule Agents.Sessions.Domain.Events.SessionServerConnectedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionServerConnected

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionServerConnected.event_type() == "sessions.session_server_connected"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionServerConnected.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionServerConnected.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.event_type == "sessions.session_server_connected"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionServerConnected.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
