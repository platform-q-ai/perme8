defmodule Agents.Sessions.Domain.Events.SessionFileEditedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionFileEdited

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    file_path: "lib/foo.ex",
    edit_summary: "updated function"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionFileEdited.event_type() == "sessions.session_file_edited"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionFileEdited.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionFileEdited.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.file_path == "lib/foo.ex"
      assert event.edit_summary == "updated function"
      assert event.event_type == "sessions.session_file_edited"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionFileEdited.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
