defmodule Agents.Sessions.Domain.Entities.QueueSnapshotTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}

  describe "new/1" do
    test "creates snapshot with default empty lanes" do
      snapshot = QueueSnapshot.new(%{user_id: "user-123"})

      assert %QueueSnapshot{} = snapshot
      assert snapshot.user_id == "user-123"
      assert snapshot.lanes.processing == []
      assert snapshot.lanes.cold == []
      assert snapshot.lanes.awaiting_feedback == []
      assert snapshot.lanes.retry_pending == []
    end

    test "applies default metadata values" do
      snapshot = QueueSnapshot.new(%{user_id: "user-123"})

      assert snapshot.metadata.concurrency_limit == 2
      assert snapshot.metadata.running_count == 0
      assert snapshot.metadata.available_slots == 2
      assert snapshot.metadata.total_queued == 0
    end
  end

  describe "total_queued/1" do
    test "sums cold and retry_pending lanes" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            cold: [LaneEntry.new(%{task_id: "cold-1"}), LaneEntry.new(%{task_id: "cold-2"})],
            retry_pending: [LaneEntry.new(%{task_id: "retry-1"})],
            processing: [LaneEntry.new(%{task_id: "proc-1"})],
            awaiting_feedback: [LaneEntry.new(%{task_id: "feedback-1"})]
          }
        })

      assert QueueSnapshot.total_queued(snapshot) == 3
    end
  end

  describe "available_slots/1" do
    test "computes concurrency_limit minus running_count" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          metadata: %{concurrency_limit: 4, running_count: 1}
        })

      assert QueueSnapshot.available_slots(snapshot) == 3
    end
  end

  describe "lane_for/2" do
    test "returns lane list for requested atom" do
      entry = LaneEntry.new(%{task_id: "task-1"})

      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{cold: [entry]}
        })

      assert QueueSnapshot.lane_for(snapshot, :cold) == [entry]
      assert QueueSnapshot.lane_for(snapshot, :processing) == []
    end
  end

  describe "to_legacy_map/1" do
    test "converts snapshot to legacy queue map shape" do
      cold =
        LaneEntry.new(%{
          task_id: "cold-1",
          instruction: "Cold task",
          status: "queued",
          lane: :cold,
          queue_position: 3
        })

      retry =
        LaneEntry.new(%{
          task_id: "retry-1",
          instruction: "Retry task",
          status: "queued",
          lane: :retry_pending,
          queue_position: 4
        })

      awaiting =
        LaneEntry.new(%{
          task_id: "awaiting-1",
          instruction: "Awaiting",
          status: "awaiting_feedback",
          lane: :awaiting_feedback
        })

      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            processing: [],
            cold: [cold],
            retry_pending: [retry],
            awaiting_feedback: [awaiting]
          },
          metadata: %{running_count: 1, concurrency_limit: 3}
        })

      legacy = QueueSnapshot.to_legacy_map(snapshot)

      assert legacy.running == 1
      assert Enum.map(legacy.queued, & &1.id) == ["cold-1", "retry-1"]
      assert Enum.map(legacy.awaiting_feedback, & &1.id) == ["awaiting-1"]
      assert legacy.concurrency_limit == 3
    end
  end
end
