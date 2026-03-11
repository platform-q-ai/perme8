defmodule Agents.Sessions.Domain.Entities.SessionTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Session

  describe "Session.new/1" do
    test "creates a session entity with provided fields" do
      queued_at = ~U[2026-03-09 10:00:00Z]

      session =
        Session.new(%{
          task_id: "task-123",
          user_id: "user-123",
          status: "queued",
          lifecycle_state: :queued_cold,
          container_id: nil,
          container_port: nil,
          session_id: "sess-123",
          instruction: "Run tests",
          error: nil,
          queue_position: 2,
          queued_at: queued_at
        })

      assert %Session{} = session
      assert session.task_id == "task-123"
      assert session.user_id == "user-123"
      assert session.status == "queued"
      assert session.lifecycle_state == :queued_cold
      assert session.container_id == nil
      assert session.container_port == nil
      assert session.session_id == "sess-123"
      assert session.instruction == "Run tests"
      assert session.error == nil
      assert session.queue_position == 2
      assert session.queued_at == queued_at
    end

    test "defaults lifecycle_state to idle" do
      session = Session.new(%{task_id: "task-123", user_id: "user-123"})

      assert session.lifecycle_state == :idle
    end
  end

  describe "Session.from_task/1" do
    test "converts task-like map into a session with derived lifecycle_state" do
      task = %{
        id: "task-123",
        user_id: "user-123",
        status: "queued",
        container_id: nil,
        container_port: nil,
        session_id: "sess-123",
        instruction: "Run tests",
        error: nil,
        queue_position: 1,
        queued_at: ~U[2026-03-09 10:00:00Z],
        started_at: nil,
        completed_at: nil
      }

      session = Session.from_task(task)

      assert session.task_id == "task-123"
      assert session.user_id == "user-123"
      assert session.status == "queued"
      assert session.lifecycle_state == :queued_cold
      assert session.container_id == nil
      assert session.container_port == nil
      assert session.session_id == "sess-123"
      assert session.instruction == "Run tests"
      assert session.error == nil
      assert session.queue_position == 1
      assert session.queued_at == ~U[2026-03-09 10:00:00Z]
      assert session.started_at == nil
      assert session.completed_at == nil
    end
  end

  describe "Session.from_task/2" do
    test "converts task-like map with runtime container metadata" do
      task = %{
        id: "task-123",
        user_id: "user-123",
        status: "pending",
        container_id: nil,
        container_port: nil,
        instruction: "Run tests"
      }

      metadata = %{container_id: "container-123", container_port: 4100}

      session = Session.from_task(task, metadata)

      assert session.task_id == "task-123"
      assert session.status == "pending"
      assert session.container_id == "container-123"
      assert session.container_port == 4100
      assert session.lifecycle_state == :pending
    end
  end

  describe "Session.valid_lifecycle_states/0" do
    test "returns the exact 11 lifecycle states" do
      assert Session.valid_lifecycle_states() == [
               :idle,
               :queued_cold,
               :queued_warm,
               :warming,
               :pending,
               :starting,
               :running,
               :awaiting_feedback,
               :completed,
               :failed,
               :cancelled
             ]
    end
  end

  describe "Session.display_name/1" do
    test "returns human-readable labels for all lifecycle states" do
      assert Session.display_name(:queued_cold) == "Queued (cold)"
      assert Session.display_name(:queued_warm) == "Queued (warm)"
      assert Session.display_name(:warming) == "Warming up"
      assert Session.display_name(:starting) == "Starting"
      assert Session.display_name(:running) == "Running"
      assert Session.display_name(:awaiting_feedback) == "Awaiting feedback"
      assert Session.display_name(:completed) == "Completed"
      assert Session.display_name(:failed) == "Failed"
      assert Session.display_name(:cancelled) == "Cancelled"
      assert Session.display_name(:idle) == "Idle"
      assert Session.display_name(:pending) == "Pending"
    end
  end

  describe "SDK tracking field defaults" do
    test "new/1 defaults SDK tracking fields" do
      session = Session.new(%{task_id: "task-123"})

      assert session.message_count == 0
      assert session.streaming_active == false
      assert session.active_tool_calls == 0
      assert session.error_category == nil
      assert session.error_recoverable == nil
      assert session.permission_context == nil
      assert session.retry_attempt == 0
      assert session.retry_message == nil
      assert session.retry_next_at == nil
      assert session.file_edits == []
      assert session.compacted == false
      assert session.sdk_session_title == nil
      assert session.sdk_share_status == nil
      assert session.last_event_id == nil
    end

    test "new/1 accepts SDK tracking field overrides" do
      session =
        Session.new(%{
          task_id: "task-123",
          message_count: 5,
          streaming_active: true,
          active_tool_calls: 2,
          error_category: :auth,
          error_recoverable: false,
          file_edits: ["lib/foo.ex"],
          compacted: true,
          sdk_session_title: "My Session",
          last_event_id: "evt-123"
        })

      assert session.message_count == 5
      assert session.streaming_active == true
      assert session.active_tool_calls == 2
      assert session.error_category == :auth
      assert session.error_recoverable == false
      assert session.file_edits == ["lib/foo.ex"]
      assert session.compacted == true
      assert session.sdk_session_title == "My Session"
      assert session.last_event_id == "evt-123"
    end
  end

  describe "Session.update/2" do
    test "creates a new struct with merged fields" do
      session = Session.new(%{task_id: "task-123", lifecycle_state: :running, message_count: 0})
      updated = Session.update(session, %{message_count: 5, streaming_active: true})

      assert updated.task_id == "task-123"
      assert updated.lifecycle_state == :running
      assert updated.message_count == 5
      assert updated.streaming_active == true
    end

    test "preserves existing fields not included in the update map" do
      session = Session.new(%{task_id: "task-123", user_id: "user-456", message_count: 3})
      updated = Session.update(session, %{streaming_active: true})

      assert updated.task_id == "task-123"
      assert updated.user_id == "user-456"
      assert updated.message_count == 3
      assert updated.streaming_active == true
    end
  end

  describe "Session.track_message/1" do
    test "increments message_count by 1" do
      session = Session.new(%{task_id: "t", message_count: 3})
      assert Session.track_message(session).message_count == 4
    end
  end

  describe "Session.remove_message/1" do
    test "decrements message_count by 1" do
      session = Session.new(%{task_id: "t", message_count: 3})
      assert Session.remove_message(session).message_count == 2
    end

    test "does not go below 0" do
      session = Session.new(%{task_id: "t", message_count: 0})
      assert Session.remove_message(session).message_count == 0
    end
  end

  describe "Session.start_streaming/1" do
    test "sets streaming_active to true" do
      session = Session.new(%{task_id: "t", streaming_active: false})
      assert Session.start_streaming(session).streaming_active == true
    end
  end

  describe "Session.stop_streaming/1" do
    test "sets streaming_active to false" do
      session = Session.new(%{task_id: "t", streaming_active: true})
      assert Session.stop_streaming(session).streaming_active == false
    end
  end

  describe "Session.increment_tool_calls/1" do
    test "increments active_tool_calls" do
      session = Session.new(%{task_id: "t", active_tool_calls: 2})
      assert Session.increment_tool_calls(session).active_tool_calls == 3
    end
  end

  describe "Session.decrement_tool_calls/1" do
    test "decrements active_tool_calls" do
      session = Session.new(%{task_id: "t", active_tool_calls: 2})
      assert Session.decrement_tool_calls(session).active_tool_calls == 1
    end

    test "does not go below 0" do
      session = Session.new(%{task_id: "t", active_tool_calls: 0})
      assert Session.decrement_tool_calls(session).active_tool_calls == 0
    end
  end

  describe "Session.record_file_edit/2" do
    test "appends file path to file_edits" do
      session = Session.new(%{task_id: "t", file_edits: []})
      updated = Session.record_file_edit(session, "lib/foo.ex")
      assert updated.file_edits == ["lib/foo.ex"]
    end

    test "deduplicates by file path" do
      session = Session.new(%{task_id: "t", file_edits: ["lib/foo.ex"]})
      updated = Session.record_file_edit(session, "lib/foo.ex")
      assert updated.file_edits == ["lib/foo.ex"]
    end

    test "preserves existing entries when adding new" do
      session = Session.new(%{task_id: "t", file_edits: ["lib/foo.ex"]})
      updated = Session.record_file_edit(session, "lib/bar.ex")
      assert "lib/foo.ex" in updated.file_edits
      assert "lib/bar.ex" in updated.file_edits
    end
  end

  describe "Session.mark_compacted/1" do
    test "sets compacted to true" do
      session = Session.new(%{task_id: "t", compacted: false})
      assert Session.mark_compacted(session).compacted == true
    end
  end
end
