defmodule AgentsWeb.SessionsLive.FollowUpDispatchTest do
  use ExUnit.Case, async: true

  alias AgentsWeb.SessionsLive.SessionStateMachine

  describe "stale_queued_message?/2" do
    test "returns true for messages older than the TTL" do
      old_time = DateTime.add(DateTime.utc_now(), -150, :second)
      msg = %{queued_at: old_time, status: "pending"}

      assert SessionStateMachine.stale_queued_message?(msg, 120)
    end

    test "returns false for recent messages" do
      recent_time = DateTime.add(DateTime.utc_now(), -10, :second)
      msg = %{queued_at: recent_time, status: "pending"}

      refute SessionStateMachine.stale_queued_message?(msg, 120)
    end

    test "returns true when queued_at is nil" do
      msg = %{queued_at: nil, status: "pending"}

      assert SessionStateMachine.stale_queued_message?(msg, 120)
    end

    test "returns false for messages with non-pending status" do
      old_time = DateTime.add(DateTime.utc_now(), -150, :second)
      msg = %{queued_at: old_time, status: "rolled_back"}

      # rolled_back messages are already resolved — not stale
      refute SessionStateMachine.stale_queued_message?(msg, 120)
    end

    test "boundary: exactly at TTL returns false" do
      # The message is exactly TTL seconds old — not yet stale
      boundary_time = DateTime.add(DateTime.utc_now(), -120, :second)
      msg = %{queued_at: boundary_time, status: "pending"}

      refute SessionStateMachine.stale_queued_message?(msg, 120)
    end

    test "uses default TTL of 120 seconds when not specified" do
      old_time = DateTime.add(DateTime.utc_now(), -121, :second)
      msg = %{queued_at: old_time, status: "pending"}

      assert SessionStateMachine.stale_queued_message?(msg)
    end
  end

  describe "mark_queued_message_status/3" do
    test "marks the matching message by correlation_key" do
      messages = [
        %{id: "q-1", correlation_key: "key-1", content: "msg1", status: "pending"},
        %{id: "q-2", correlation_key: "key-2", content: "msg2", status: "pending"}
      ]

      result = SessionStateMachine.mark_queued_message_status(messages, "key-2", "timed_out")
      assert Enum.find(result, &(&1.id == "q-2")).status == "timed_out"
      assert Enum.find(result, &(&1.id == "q-1")).status == "pending"
    end

    test "falls back to id match when correlation_key is missing" do
      messages = [
        %{id: "q-1", content: "msg1", status: "pending"}
      ]

      result = SessionStateMachine.mark_queued_message_status(messages, "q-1", "rolled_back")
      assert hd(result).status == "rolled_back"
    end

    test "leaves messages unchanged when no match" do
      messages = [
        %{id: "q-1", correlation_key: "key-1", content: "msg1", status: "pending"}
      ]

      result =
        SessionStateMachine.mark_queued_message_status(messages, "key-nonexistent", "timed_out")

      assert hd(result).status == "pending"
    end
  end
end
