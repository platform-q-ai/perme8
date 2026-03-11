defmodule Agents.Sessions.Domain.Policies.SdkEventPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Session
  alias Agents.Sessions.Domain.Policies.SdkEventPolicy

  defp running_session(overrides \\ %{}) do
    Session.new(
      Map.merge(%{task_id: "task-1", user_id: "user-1", lifecycle_state: :running}, overrides)
    )
  end

  defp idle_session(overrides \\ %{}) do
    Session.new(
      Map.merge(%{task_id: "task-1", user_id: "user-1", lifecycle_state: :idle}, overrides)
    )
  end

  defp awaiting_session(overrides \\ %{}) do
    Session.new(
      Map.merge(
        %{
          task_id: "task-1",
          user_id: "user-1",
          lifecycle_state: :awaiting_feedback,
          permission_context: %{tool: "bash", action: "run command"}
        },
        overrides
      )
    )
  end

  defp failed_session(overrides \\ %{}) do
    Session.new(
      Map.merge(%{task_id: "task-1", user_id: "user-1", lifecycle_state: :failed}, overrides)
    )
  end

  defp sdk_event(type, properties) do
    %{"type" => type, "properties" => properties}
  end

  describe "session.status - busy" do
    test "running session stays running, no state change events" do
      session = running_session()
      event = sdk_event("session.status", %{"status" => "busy"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :running
      refute Enum.any?(events, &match?(%{event_type: "sessions.session_state_changed"}, &1))
    end
  end

  describe "session.status - idle" do
    test "running session transitions to completed" do
      session = running_session()
      event = sdk_event("session.status", %{"status" => "idle"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :completed
      assert updated.streaming_active == false

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :completed
             end)
    end

    test "idle session stays idle, no transition" do
      session = idle_session()
      event = sdk_event("session.status", %{"status" => "idle"})

      assert {:skip, :no_transition} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "session.status - retry" do
    test "running session stays running with retry metadata" do
      session = running_session()

      event =
        sdk_event("session.status", %{
          "status" => "retry",
          "attempt" => 2,
          "message" => "Rate limited",
          "next" => "2026-03-11T12:00:00Z"
        })

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :running
      assert updated.retry_attempt == 2
      assert updated.retry_message == "Rate limited"
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_retrying" end)
    end
  end

  describe "session.error - terminal" do
    test "running session transitions to failed" do
      session = running_session()
      event = sdk_event("session.error", %{"category" => "auth", "message" => "Invalid API key"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :failed
      assert updated.error == "Invalid API key"
      assert updated.error_category == :auth
      assert updated.error_recoverable == false

      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_error_occurred" end)

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :failed
             end)
    end

    test "already failed session returns skip" do
      session = failed_session()
      event = sdk_event("session.error", %{"category" => "auth", "message" => "Error"})

      assert {:skip, :already_terminal} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "session.error - recoverable" do
    test "running session stays running with error metadata" do
      session = running_session()
      event = sdk_event("session.error", %{"category" => "api", "message" => "Rate limited"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :running
      assert updated.error == "Rate limited"
      assert updated.error_category == :api
      assert updated.error_recoverable == true

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_error_occurred" and e.recoverable == true
             end)

      refute Enum.any?(events, fn e -> e.event_type == "sessions.session_state_changed" end)
    end
  end

  describe "permission.updated" do
    test "running session transitions to awaiting_feedback" do
      session = running_session()

      event =
        sdk_event("permission.updated", %{
          "id" => "perm-1",
          "tool" => "bash",
          "action" => "run command"
        })

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :awaiting_feedback
      assert updated.permission_context == %{tool: "bash", action: "run command", id: "perm-1"}

      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_permission_requested" end)

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and
                 e.to_state == :awaiting_feedback
             end)
    end

    test "on non-running session returns skip" do
      session = idle_session()

      event =
        sdk_event("permission.updated", %{"id" => "perm-1", "tool" => "bash", "action" => "x"})

      assert {:skip, :invalid_state} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "permission.replied" do
    test "awaiting session transitions back to running on allow" do
      session = awaiting_session()
      event = sdk_event("permission.replied", %{"id" => "perm-1", "outcome" => "allowed"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :running
      assert updated.permission_context == nil

      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_permission_resolved" end)

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :running
             end)
    end

    test "awaiting session transitions to cancelled on deny" do
      session = awaiting_session()
      event = sdk_event("permission.replied", %{"id" => "perm-1", "outcome" => "denied"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :cancelled

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :cancelled
             end)
    end
  end

  describe "message.updated" do
    test "increments message count and emits SessionMessageUpdated" do
      session = running_session(%{message_count: 3})
      event = sdk_event("message.updated", %{"id" => "msg-1", "role" => "assistant"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.message_count == 4
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_message_updated" end)
    end
  end

  describe "message.removed" do
    test "decrements message count" do
      session = running_session(%{message_count: 3})
      event = sdk_event("message.removed", %{"id" => "msg-1"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.message_count == 2
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_message_updated" end)
    end
  end

  describe "message.part.updated" do
    test "text delta sets streaming active" do
      session = running_session(%{streaming_active: false})
      event = sdk_event("message.part.updated", %{"type" => "text", "delta" => "hello"})

      assert {:ok, updated, _events} = SdkEventPolicy.apply_event(session, event)
      assert updated.streaming_active == true
    end

    test "tool-start increments active tool calls" do
      session = running_session(%{active_tool_calls: 1})
      event = sdk_event("message.part.updated", %{"type" => "tool-start"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.active_tool_calls == 2
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_message_updated" end)
    end

    test "tool with state=completed decrements active tool calls" do
      session = running_session(%{active_tool_calls: 2})
      event = sdk_event("message.part.updated", %{"type" => "tool", "state" => "completed"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.active_tool_calls == 1
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_message_updated" end)
    end
  end

  describe "message.part.removed" do
    test "returns ok with no state change" do
      session = running_session()
      event = sdk_event("message.part.removed", %{})

      assert {:ok, _updated, _events} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "session.idle" do
    test "running session transitions to completed and stops streaming" do
      session = running_session(%{streaming_active: true})
      event = sdk_event("session.idle", %{})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :completed
      assert updated.streaming_active == false

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :completed
             end)
    end

    test "idle session is a no-op" do
      session = idle_session()
      event = sdk_event("session.idle", %{})

      assert {:skip, :no_transition} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "session.created" do
    test "sets session metadata from event" do
      session = running_session()
      event = sdk_event("session.created", %{"title" => "New Session"})

      assert {:ok, updated, _events} = SdkEventPolicy.apply_event(session, event)
      assert updated.sdk_session_title == "New Session"
    end
  end

  describe "session.updated" do
    test "updates metadata and emits SessionMetadataUpdated" do
      session = running_session()
      event = sdk_event("session.updated", %{"title" => "Updated Title", "share" => "team"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.sdk_session_title == "Updated Title"
      assert updated.sdk_share_status == "team"
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_metadata_updated" end)
    end
  end

  describe "session.deleted" do
    test "non-terminal session transitions to cancelled" do
      session = running_session()
      event = sdk_event("session.deleted", %{})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :cancelled

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :cancelled
             end)
    end

    test "already terminal session returns skip" do
      session = failed_session()
      event = sdk_event("session.deleted", %{})

      assert {:skip, :already_terminal} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "session.compacted" do
    test "marks compacted and emits SessionCompacted" do
      session = running_session(%{compacted: false})
      event = sdk_event("session.compacted", %{})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.compacted == true
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_compacted" end)
    end
  end

  describe "session.diff" do
    test "emits SessionDiffProduced" do
      session = running_session()
      event = sdk_event("session.diff", %{"summary" => "+10 -3 lib/foo.ex"})

      assert {:ok, _updated, events} = SdkEventPolicy.apply_event(session, event)
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_diff_produced" end)
    end
  end

  describe "server.connected" do
    test "emits SessionServerConnected with no state change" do
      session = running_session()
      event = sdk_event("server.connected", %{})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :running
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_server_connected" end)
    end
  end

  describe "server.instance.disposed" do
    test "running session transitions to failed" do
      session = running_session()
      event = sdk_event("server.instance.disposed", %{})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :failed

      assert Enum.any?(events, fn e ->
               e.event_type == "sessions.session_state_changed" and e.to_state == :failed
             end)

      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_error_occurred" end)
    end

    test "awaiting_feedback session transitions to failed" do
      session = awaiting_session()
      event = sdk_event("server.instance.disposed", %{})

      assert {:ok, updated, _events} = SdkEventPolicy.apply_event(session, event)
      assert updated.lifecycle_state == :failed
    end

    test "already terminal session returns skip" do
      session = failed_session()
      event = sdk_event("server.instance.disposed", %{})

      assert {:skip, :already_terminal} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "file.edited" do
    test "records file edit and emits SessionFileEdited" do
      session = running_session(%{file_edits: []})
      event = sdk_event("file.edited", %{"path" => "lib/foo.ex"})

      assert {:ok, updated, events} = SdkEventPolicy.apply_event(session, event)
      assert "lib/foo.ex" in updated.file_edits
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_file_edited" end)
    end
  end

  describe "unhandled event" do
    test "returns skip for unhandled event type" do
      session = running_session()
      event = sdk_event("pty.created", %{})

      assert {:skip, :not_relevant} = SdkEventPolicy.apply_event(session, event)
    end
  end

  describe "terminal state guard" do
    test "most events are skipped on terminal sessions" do
      for type <- [
            "session.status",
            "session.error",
            "permission.updated",
            "permission.replied",
            "message.updated",
            "message.removed",
            "session.idle",
            "session.deleted",
            "file.edited"
          ] do
        session = Session.new(%{task_id: "t", user_id: "u", lifecycle_state: :completed})

        event =
          sdk_event(type, %{
            "status" => "busy",
            "category" => "auth",
            "message" => "err",
            "id" => "x",
            "tool" => "t",
            "action" => "a",
            "outcome" => "allowed",
            "path" => "lib/x.ex"
          })

        assert {:skip, :already_terminal} = SdkEventPolicy.apply_event(session, event),
               "expected #{type} to be skipped on terminal session"
      end
    end

    test "observability events still work on terminal sessions" do
      session = Session.new(%{task_id: "t", user_id: "u", lifecycle_state: :completed})
      event = sdk_event("server.connected", %{})

      assert {:ok, _updated, events} = SdkEventPolicy.apply_event(session, event)
      assert Enum.any?(events, fn e -> e.event_type == "sessions.session_server_connected" end)
    end

    test "metadata events still work on terminal sessions" do
      session = Session.new(%{task_id: "t", user_id: "u", lifecycle_state: :completed})
      event = sdk_event("session.updated", %{"title" => "Updated"})

      assert {:ok, updated, _events} = SdkEventPolicy.apply_event(session, event)
      assert updated.sdk_session_title == "Updated"
    end

    test "compacted events still work on terminal sessions" do
      session = Session.new(%{task_id: "t", user_id: "u", lifecycle_state: :completed})
      event = sdk_event("session.compacted", %{})

      assert {:ok, updated, _events} = SdkEventPolicy.apply_event(session, event)
      assert updated.compacted == true
    end
  end
end
