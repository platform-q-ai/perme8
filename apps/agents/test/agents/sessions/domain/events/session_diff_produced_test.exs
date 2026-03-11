defmodule Agents.Sessions.Domain.Events.SessionDiffProducedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionDiffProduced

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    diff_summary: "3 files changed"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionDiffProduced.event_type() == "sessions.session_diff_produced"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionDiffProduced.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionDiffProduced.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.diff_summary == "3 files changed"
      assert event.event_type == "sessions.session_diff_produced"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionDiffProduced.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
