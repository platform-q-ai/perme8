defmodule Agents.Sessions.Domain.Events.SessionMetadataUpdatedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionMetadataUpdated

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    title: "My Session",
    share_status: "private"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionMetadataUpdated.event_type() == "sessions.session_metadata_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionMetadataUpdated.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionMetadataUpdated.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.title == "My Session"
      assert event.share_status == "private"
      assert event.event_type == "sessions.session_metadata_updated"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionMetadataUpdated.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
