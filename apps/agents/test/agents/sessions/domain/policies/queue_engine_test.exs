defmodule Agents.Sessions.Domain.Policies.QueueEngineTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias Agents.Sessions.Domain.Policies.QueueEngine

  describe "assign_lane/1" do
    test "returns processing for pending, starting, and running statuses" do
      assert QueueEngine.assign_lane(task(status: "pending")) == :processing
      assert QueueEngine.assign_lane(task(status: "starting")) == :processing
      assert QueueEngine.assign_lane(task(status: "running")) == :processing
    end

    test "returns awaiting_feedback for awaiting_feedback status" do
      assert QueueEngine.assign_lane(task(status: "awaiting_feedback")) == :awaiting_feedback
    end

    test "returns retry_pending for queued tasks with retry_count greater than zero" do
      assert QueueEngine.assign_lane(task(status: "queued", retry_count: 1)) == :retry_pending
    end

    test "returns warm for queued tasks with a real container id" do
      assert QueueEngine.assign_lane(task(status: "queued", container_id: "container-123")) ==
               :warm
    end

    test "returns cold for queued tasks without a real container id" do
      assert QueueEngine.assign_lane(task(status: "queued", container_id: nil)) == :cold

      assert QueueEngine.assign_lane(task(status: "queued", container_id: "task:placeholder")) ==
               :cold
    end

    test "returns terminal for completed, failed, and cancelled statuses" do
      assert QueueEngine.assign_lane(task(status: "completed")) == :terminal
      assert QueueEngine.assign_lane(task(status: "failed")) == :terminal
      assert QueueEngine.assign_lane(task(status: "cancelled")) == :terminal
    end
  end

  describe "classify_warm_state/1" do
    test "returns cold for nil or task-prefixed container ids" do
      assert QueueEngine.classify_warm_state(task(container_id: nil, container_port: nil)) ==
               :cold

      assert QueueEngine.classify_warm_state(task(container_id: "task:abc", container_port: nil)) ==
               :cold
    end

    test "returns warm for real container id without a port" do
      assert QueueEngine.classify_warm_state(
               task(container_id: "container-123", container_port: nil)
             ) ==
               :warm
    end

    test "returns warm for real container id with port" do
      assert QueueEngine.classify_warm_state(
               task(container_id: "container-123", container_port: 4000)
             ) ==
               :warm
    end

    test "returns hot for running tasks with container and port" do
      assert QueueEngine.classify_warm_state(
               task(status: "running", container_id: "container-123", container_port: 4000)
             ) == :hot
    end

    test "maps lifecycle-derived states to warm state classifications" do
      assert QueueEngine.classify_warm_state(task(status: "queued", container_id: nil)) == :cold

      assert QueueEngine.classify_warm_state(task(status: "queued", container_id: "container-1")) ==
               :warm

      assert QueueEngine.classify_warm_state(task(status: "pending", container_id: nil)) == :warm
      assert QueueEngine.classify_warm_state(task(status: "starting", container_id: nil)) == :warm

      assert QueueEngine.classify_warm_state(task(status: "awaiting_feedback", container_id: nil)) ==
               :cold
    end
  end

  describe "build_snapshot/2" do
    test "builds snapshot from tasks and config" do
      started_early = ~U[2026-01-01 00:00:00Z]
      started_late = ~U[2026-01-01 00:01:00Z]

      tasks = [
        task(id: "processing-2", status: "running", started_at: started_late),
        task(id: "processing-1", status: "pending", started_at: started_early),
        task(id: "warm-2", status: "queued", queue_position: 3, container_id: "container-2"),
        task(id: "warm-1", status: "queued", queue_position: 1, container_id: "container-1"),
        task(id: "cold-2", status: "queued", queue_position: 4, container_id: nil),
        task(id: "cold-1", status: "queued", queue_position: 2, container_id: "task:placeholder"),
        task(id: "retry", status: "queued", queue_position: 5, retry_count: 2),
        task(id: "feedback", status: "awaiting_feedback"),
        task(id: "done", status: "completed")
      ]

      config = %{concurrency_limit: 3, warm_cache_limit: 2, user_id: "user-123"}

      snapshot = QueueEngine.build_snapshot(tasks, config)

      assert %QueueSnapshot{} = snapshot
      assert snapshot.user_id == "user-123"
      assert Enum.map(snapshot.lanes.processing, & &1.task_id) == ["processing-1", "processing-2"]
      assert Enum.map(snapshot.lanes.warm, & &1.task_id) == ["warm-1", "warm-2"]
      assert Enum.map(snapshot.lanes.cold, & &1.task_id) == ["cold-1", "cold-2"]
      assert Enum.map(snapshot.lanes.retry_pending, & &1.task_id) == ["retry"]
      assert Enum.map(snapshot.lanes.awaiting_feedback, & &1.task_id) == ["feedback"]

      refute Enum.any?(snapshot.lanes.processing, &(&1.task_id == "done"))

      assert snapshot.metadata.running_count == 2
      assert snapshot.metadata.concurrency_limit == 3
      assert snapshot.metadata.warm_cache_limit == 2
      assert snapshot.metadata.available_slots == 1
      assert snapshot.metadata.total_queued == 5
    end
  end

  describe "can_transition?/2" do
    test "returns true for valid transitions" do
      assert QueueEngine.can_transition?("queued", "pending")
      assert QueueEngine.can_transition?("pending", "starting")
      assert QueueEngine.can_transition?("starting", "running")
      assert QueueEngine.can_transition?("running", "completed")
      assert QueueEngine.can_transition?("running", "failed")
      assert QueueEngine.can_transition?("running", "cancelled")
      assert QueueEngine.can_transition?("queued", "cancelled")
      assert QueueEngine.can_transition?("awaiting_feedback", "queued")
      assert QueueEngine.can_transition?("pending", "cancelled")
      assert QueueEngine.can_transition?("starting", "cancelled")
      assert QueueEngine.can_transition?("running", "awaiting_feedback")
    end

    test "returns false for invalid transitions" do
      refute QueueEngine.can_transition?("completed", "running")
      refute QueueEngine.can_transition?("cancelled", "pending")
      refute QueueEngine.can_transition?("failed", "running")
      refute QueueEngine.can_transition?("queued", "running")
    end
  end

  describe "promotable_tasks/1" do
    test "returns warm then cold tasks sorted by queue_position" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            warm: [
              LaneEntry.new(%{task_id: "warm-2", queue_position: 3}),
              LaneEntry.new(%{task_id: "warm-1", queue_position: 1})
            ],
            cold: [
              LaneEntry.new(%{task_id: "cold-2", queue_position: 4}),
              LaneEntry.new(%{task_id: "cold-1", queue_position: 2})
            ]
          }
        })

      promotable = QueueEngine.promotable_tasks(snapshot)

      assert Enum.map(promotable, & &1.task_id) == ["warm-1", "warm-2", "cold-1", "cold-2"]
    end
  end

  describe "tasks_to_promote/2" do
    test "returns up to N promotable tasks" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            warm: [
              LaneEntry.new(%{task_id: "warm-1", queue_position: 1}),
              LaneEntry.new(%{task_id: "warm-2", queue_position: 2})
            ],
            cold: [LaneEntry.new(%{task_id: "cold-1", queue_position: 3})]
          }
        })

      assert Enum.map(QueueEngine.tasks_to_promote(snapshot, 2), & &1.task_id) == [
               "warm-1",
               "warm-2"
             ]

      assert QueueEngine.tasks_to_promote(snapshot, 0) == []
    end
  end

  describe "build_snapshot/2 light image awareness" do
    test "running_count excludes light image processing tasks" do
      tasks = [
        task(id: "heavy-1", status: "running", image: "perme8-opencode"),
        task(id: "light-1", status: "running", image: "perme8-opencode-light"),
        task(id: "heavy-2", status: "pending", image: "perme8-opencode"),
        task(id: "light-2", status: "pending", image: "perme8-opencode-light")
      ]

      config = %{concurrency_limit: 2, user_id: "user-123"}
      snapshot = QueueEngine.build_snapshot(tasks, config)

      # Only heavyweight tasks count toward running_count
      assert snapshot.metadata.running_count == 2
      # available_slots based on heavyweight-only count
      assert snapshot.metadata.available_slots == 0
      # All 4 are in the processing lane
      assert length(snapshot.lanes.processing) == 4
    end

    test "available_slots unaffected by light image processing tasks" do
      tasks = [
        task(id: "light-1", status: "running", image: "perme8-opencode-light"),
        task(id: "light-2", status: "running", image: "perme8-opencode-light"),
        task(id: "queued-1", status: "queued", queue_position: 1, image: "perme8-opencode")
      ]

      config = %{concurrency_limit: 2, user_id: "user-123"}
      snapshot = QueueEngine.build_snapshot(tasks, config)

      # Light images don't count -> running_count = 0
      assert snapshot.metadata.running_count == 0
      assert snapshot.metadata.available_slots == 2
    end

    test "to_lane_entry populates image field" do
      tasks = [task(id: "task-1", status: "running", image: "perme8-opencode-light")]
      config = %{concurrency_limit: 2, user_id: "user-123"}
      snapshot = QueueEngine.build_snapshot(tasks, config)

      [entry] = snapshot.lanes.processing
      assert entry.image == "perme8-opencode-light"
    end

    test "to_lane_entry defaults image to nil when not present" do
      tasks = [task(id: "task-1", status: "running")]
      config = %{concurrency_limit: 2, user_id: "user-123"}
      snapshot = QueueEngine.build_snapshot(tasks, config)

      [entry] = snapshot.lanes.processing
      assert entry.image == nil
    end
  end

  describe "light_image_tasks_to_promote/1" do
    test "returns all queued light image tasks regardless of available slots" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            processing: [
              LaneEntry.new(%{task_id: "heavy-1", image: "perme8-opencode", lane: :processing}),
              LaneEntry.new(%{task_id: "heavy-2", image: "perme8-opencode", lane: :processing})
            ],
            warm: [
              LaneEntry.new(%{
                task_id: "light-warm",
                image: "perme8-opencode-light",
                queue_position: 1,
                lane: :warm
              }),
              LaneEntry.new(%{
                task_id: "heavy-warm",
                image: "perme8-opencode",
                queue_position: 2,
                lane: :warm
              })
            ],
            cold: [
              LaneEntry.new(%{
                task_id: "light-cold",
                image: "perme8-opencode-light",
                queue_position: 3,
                lane: :cold
              }),
              LaneEntry.new(%{
                task_id: "heavy-cold",
                image: "perme8-opencode",
                queue_position: 4,
                lane: :cold
              })
            ]
          },
          metadata: %{concurrency_limit: 2, running_count: 2}
        })

      promotable = QueueEngine.light_image_tasks_to_promote(snapshot)

      assert Enum.map(promotable, & &1.task_id) == ["light-warm", "light-cold"]
    end

    test "returns empty list when no queued light image tasks exist" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            warm: [
              LaneEntry.new(%{
                task_id: "heavy-1",
                image: "perme8-opencode",
                queue_position: 1,
                lane: :warm
              })
            ],
            cold: []
          },
          metadata: %{concurrency_limit: 2, running_count: 0}
        })

      assert QueueEngine.light_image_tasks_to_promote(snapshot) == []
    end
  end

  describe "heavyweight_tasks_to_promote/2" do
    test "returns only heavyweight promotable tasks up to available slots" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            warm: [
              LaneEntry.new(%{
                task_id: "light-1",
                image: "perme8-opencode-light",
                queue_position: 1,
                lane: :warm
              }),
              LaneEntry.new(%{
                task_id: "heavy-1",
                image: "perme8-opencode",
                queue_position: 2,
                lane: :warm
              })
            ],
            cold: [
              LaneEntry.new(%{
                task_id: "heavy-2",
                image: "perme8-opencode",
                queue_position: 3,
                lane: :cold
              })
            ]
          },
          metadata: %{concurrency_limit: 2, running_count: 1}
        })

      promotable = QueueEngine.heavyweight_tasks_to_promote(snapshot, 1)

      assert Enum.map(promotable, & &1.task_id) == ["heavy-1"]
    end

    test "returns empty when no slots available" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            warm: [
              LaneEntry.new(%{
                task_id: "heavy-1",
                image: "perme8-opencode",
                queue_position: 1,
                lane: :warm
              })
            ]
          },
          metadata: %{concurrency_limit: 1, running_count: 1}
        })

      assert QueueEngine.heavyweight_tasks_to_promote(snapshot, 0) == []
    end
  end

  defp task(overrides) do
    Map.merge(
      %{
        id: "task-1",
        instruction: "Test task",
        status: "queued",
        container_id: nil,
        container_port: nil,
        queue_position: nil,
        retry_count: 0,
        error: nil,
        queued_at: nil,
        started_at: nil,
        user_id: "user-123",
        image: nil
      },
      Map.new(overrides)
    )
  end
end
