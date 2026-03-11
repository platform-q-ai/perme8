defmodule Agents.Sessions.Domain.Events.SessionPermissionResolvedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionPermissionResolved

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    permission_id: "perm-123",
    outcome: :allowed
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionPermissionResolved.event_type() == "sessions.session_permission_resolved"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionPermissionResolved.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionPermissionResolved.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.permission_id == "perm-123"
      assert event.outcome == :allowed
      assert event.event_type == "sessions.session_permission_resolved"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionPermissionResolved.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
