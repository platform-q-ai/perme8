defmodule Agents.Sessions.Domain.Policies.QueueEngineTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias Agents.Sessions.Domain.Policies.QueueEngine

  describe "assign_lane/1" do
    test "treats queued tasks as cold unless retry-pending" do
      assert QueueEngine.assign_lane(task(status: "queued", container_id: nil)) == :cold

      assert QueueEngine.assign_lane(task(status: "queued", container_id: "container-123")) ==
               :cold

      assert QueueEngine.assign_lane(task(status: "queued", retry_count: 1)) == :retry_pending
    end
  end

  describe "classify_warm_state/1" do
    test "still derives warm-state metadata from lifecycle" do
      assert QueueEngine.classify_warm_state(task(status: "queued", container_id: nil)) == :cold

      assert QueueEngine.classify_warm_state(task(status: "queued", container_id: "container-1")) ==
               :warm

      assert QueueEngine.classify_warm_state(
               task(status: "running", container_id: "container-1", container_port: 4000)
             ) == :hot
    end
  end

  describe "build_snapshot/2" do
    test "builds processing, cold, retry, and awaiting-feedback lanes" do
      tasks = [
        task(id: "processing-1", status: "running", started_at: ~U[2026-01-01 00:00:00Z]),
        task(id: "queued-2", status: "queued", queue_position: 2, container_id: "container-2"),
        task(id: "queued-1", status: "queued", queue_position: 1, container_id: nil),
        task(id: "retry", status: "queued", queue_position: 3, retry_count: 1),
        task(id: "feedback", status: "awaiting_feedback"),
        task(id: "done", status: "completed")
      ]

      snapshot = QueueEngine.build_snapshot(tasks, %{concurrency_limit: 3, user_id: "user-123"})

      assert %QueueSnapshot{} = snapshot
      assert Enum.map(snapshot.lanes.processing, & &1.task_id) == ["processing-1"]
      assert Enum.map(snapshot.lanes.cold, & &1.task_id) == ["queued-1", "queued-2"]
      assert Enum.map(snapshot.lanes.retry_pending, & &1.task_id) == ["retry"]
      assert Enum.map(snapshot.lanes.awaiting_feedback, & &1.task_id) == ["feedback"]
      assert snapshot.metadata.running_count == 1
      assert snapshot.metadata.available_slots == 2
      assert snapshot.metadata.total_queued == 3
    end
  end

  describe "promotion helpers" do
    test "promotable_tasks/1 returns queued cold tasks in order" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            cold: [
              LaneEntry.new(%{task_id: "cold-2", queue_position: 2}),
              LaneEntry.new(%{task_id: "cold-1", queue_position: 1})
            ]
          }
        })

      assert Enum.map(QueueEngine.promotable_tasks(snapshot), & &1.task_id) == [
               "cold-1",
               "cold-2"
             ]

      assert Enum.map(QueueEngine.tasks_to_promote(snapshot, 1), & &1.task_id) == ["cold-1"]
    end

    test "light_image_tasks_to_promote/1 and heavyweight_tasks_to_promote/2 split queued cold tasks by image" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-123",
          lanes: %{
            cold: [
              LaneEntry.new(%{
                task_id: "light",
                queue_position: 1,
                image: "perme8-opencode-light"
              }),
              LaneEntry.new(%{task_id: "heavy", queue_position: 2, image: "perme8-opencode"})
            ]
          }
        })

      assert Enum.map(QueueEngine.light_image_tasks_to_promote(snapshot), & &1.task_id) == [
               "light"
             ]

      assert Enum.map(QueueEngine.heavyweight_tasks_to_promote(snapshot, 1), & &1.task_id) == [
               "heavy"
             ]
    end
  end

  defp task(overrides) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        status: "queued",
        queue_position: nil,
        retry_count: 0,
        container_id: nil,
        container_port: nil,
        started_at: nil,
        image: "perme8-opencode"
      },
      Enum.into(overrides, %{})
    )
  end
end
