defmodule Agents.Sessions.Domain.Events.QueueEventsTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.{
    QueueSnapshotUpdated,
    TaskLaneChanged,
    TaskRetryScheduled
  }

  describe "TaskLaneChanged.new/1" do
    test "creates a valid lane change event" do
      event =
        TaskLaneChanged.new(%{
          aggregate_id: "task-123",
          actor_id: "user-123",
          task_id: "task-123",
          user_id: "user-123",
          from_lane: :cold,
          to_lane: :warm
        })

      assert event.event_type == "sessions.task_lane_changed"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.from_lane == :cold
      assert event.to_lane == :warm
    end
  end

  describe "TaskRetryScheduled.new/1" do
    test "creates a valid retry scheduled event" do
      next_retry_at = ~U[2026-03-01 00:00:00Z]

      event =
        TaskRetryScheduled.new(%{
          aggregate_id: "task-123",
          actor_id: "user-123",
          task_id: "task-123",
          user_id: "user-123",
          retry_count: 2,
          next_retry_at: next_retry_at
        })

      assert event.event_type == "sessions.task_retry_scheduled"
      assert event.aggregate_type == "task"
      assert event.task_id == "task-123"
      assert event.user_id == "user-123"
      assert event.retry_count == 2
      assert event.next_retry_at == next_retry_at
    end
  end

  describe "QueueSnapshotUpdated.new/1" do
    test "creates a valid queue snapshot updated event" do
      snapshot = %{metadata: %{total_queued: 3}}

      event =
        QueueSnapshotUpdated.new(%{
          aggregate_id: "queue-user-123",
          actor_id: "user-123",
          user_id: "user-123",
          snapshot: snapshot
        })

      assert event.event_type == "sessions.queue_snapshot_updated"
      assert event.aggregate_type == "queue"
      assert event.user_id == "user-123"
      assert event.snapshot == snapshot
    end
  end
end
