defmodule Agents.Sessions.Domain.Entities.QueueSnapshotTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}

  describe "new/1" do
    test "creates snapshot with default empty lanes" do
      snapshot = QueueSnapshot.new(%{user_id: "user-123"})

      assert %QueueSnapshot{} = snapshot
      assert snapshot.user_id == "user-123"
      assert snapshot.lanes.processing == []
      assert snapshot.lanes.warm == []
      assert snapshot.lanes.cold == []
      assert snapshot.lanes.awaiting_feedback == []
      assert snapshot.lanes.retry_pending == []
    end

    test "applies default metadata values" do
      snapshot = QueueSnapshot.new(%{user_id: "user-123"})

      assert snapshot.metadata.concurrency_limit == 2
      assert snapshot.metadata.warm_cache_limit == 2
      assert snapshot.metadata.running_count == 0
      assert snapshot.metadata.available_slots == 2
      assert snapshot.metadata.total_queued == 0
    end
  end

  describe "total_queued/1" do
    test "sums warm, cold, and retry_pending lanes" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            warm: [LaneEntry.new(%{task_id: "warm-1"})],
            cold: [LaneEntry.new(%{task_id: "cold-1"}), LaneEntry.new(%{task_id: "cold-2"})],
            retry_pending: [LaneEntry.new(%{task_id: "retry-1"})],
            processing: [LaneEntry.new(%{task_id: "proc-1"})],
            awaiting_feedback: [LaneEntry.new(%{task_id: "feedback-1"})]
          }
        })

      assert QueueSnapshot.total_queued(snapshot) == 4
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
          lanes: %{warm: [entry]}
        })

      assert QueueSnapshot.lane_for(snapshot, :warm) == [entry]
      assert QueueSnapshot.lane_for(snapshot, :processing) == []
    end
  end
end
