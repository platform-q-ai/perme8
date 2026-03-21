defmodule Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo do
  def get_task(task_id) do
    send(self(), {:get_task, task_id})
    %{id: task_id, user_id: "user-1", status: "queued"}
  end

  def update_task_status(task, attrs) do
    send(self(), {:update_task_status, task.id, attrs})
    {:ok, Map.merge(task, attrs)}
  end
end

defmodule Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus do
  def emit(event) do
    send(self(), {:emit, event})
    :ok
  end
end

defmodule Agents.Sessions.Application.UseCases.PromoteTaskTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.UseCases.PromoteTask
  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias Agents.Sessions.Domain.Events.{TaskLaneChanged, TaskPromoted}

  describe "execute/2" do
    test "promotes queued tasks by queue position" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            cold: [
              LaneEntry.new(%{task_id: "cold-2", queue_position: 2, lane: :cold}),
              LaneEntry.new(%{task_id: "cold-1", queue_position: 1, lane: :cold})
            ]
          },
          metadata: %{concurrency_limit: 2, running_count: 1}
        })

      assert {:ok, [promoted]} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      assert promoted.id == "cold-1"
      assert_receive {:get_task, "cold-1"}

      assert_receive {:update_task_status, "cold-1",
                      %{status: "pending", queue_position: nil, queued_at: nil}}

      refute_received {:get_task, "cold-2"}
    end

    test "respects available_slots limit" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            cold: [
              LaneEntry.new(%{task_id: "cold-0", queue_position: 1, lane: :cold}),
              LaneEntry.new(%{task_id: "cold-1", queue_position: 2, lane: :cold}),
              LaneEntry.new(%{task_id: "cold-2", queue_position: 3, lane: :cold})
            ]
          },
          metadata: %{concurrency_limit: 3, running_count: 1}
        })

      assert {:ok, promoted} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      assert Enum.map(promoted, & &1.id) == ["cold-0", "cold-1"]
      refute_received {:get_task, "cold-2"}
    end

    test "emits TaskPromoted and TaskLaneChanged events" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            cold: [LaneEntry.new(%{task_id: "cold-1", queue_position: 1, lane: :cold})]
          },
          metadata: %{concurrency_limit: 1, running_count: 0}
        })

      assert {:ok, [_]} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      assert_receive {:emit, %TaskPromoted{} = promoted_event}
      assert promoted_event.task_id == "cold-1"
      assert promoted_event.user_id == "user-1"

      assert_receive {:emit, %TaskLaneChanged{} = lane_event}
      assert lane_event.task_id == "cold-1"
      assert lane_event.from_lane == :cold
      assert lane_event.to_lane == :processing
    end

    test "does not promote when no slots are available" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            cold: [LaneEntry.new(%{task_id: "cold-1", queue_position: 1, lane: :cold})]
          },
          metadata: %{concurrency_limit: 1, running_count: 1}
        })

      assert {:ok, []} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      refute_received {:get_task, _}
      refute_received {:emit, _}
    end

    test "returns empty list when no promotable tasks exist" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{cold: []},
          metadata: %{concurrency_limit: 2, running_count: 0}
        })

      assert {:ok, []} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )
    end

    test "promotes light image tasks even when no heavyweight slots available" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            processing: [
              LaneEntry.new(%{
                task_id: "heavy-running",
                image: "perme8-opencode",
                lane: :processing
              })
            ],
            cold: [
              LaneEntry.new(%{
                task_id: "light-1",
                image: "perme8-opencode-light",
                queue_position: 1,
                lane: :cold
              }),
              LaneEntry.new(%{
                task_id: "heavy-queued",
                image: "perme8-opencode",
                queue_position: 2,
                lane: :cold
              })
            ]
          },
          metadata: %{concurrency_limit: 1, running_count: 1}
        })

      assert {:ok, promoted} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      assert Enum.map(promoted, & &1.id) == ["light-1"]
      assert_receive {:get_task, "light-1"}
      refute_received {:get_task, "heavy-queued"}
    end

    test "promotes both light and heavyweight tasks when slots available" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            cold: [
              LaneEntry.new(%{
                task_id: "light-1",
                image: "perme8-opencode-light",
                queue_position: 1,
                lane: :cold
              }),
              LaneEntry.new(%{
                task_id: "heavy-1",
                image: "perme8-opencode",
                queue_position: 2,
                lane: :cold
              })
            ]
          },
          metadata: %{concurrency_limit: 2, running_count: 0}
        })

      assert {:ok, promoted} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      assert Enum.map(promoted, & &1.id) == ["light-1", "heavy-1"]
    end

    test "does not double-promote light image tasks" do
      snapshot =
        QueueSnapshot.new(%{
          user_id: "user-1",
          lanes: %{
            cold: [
              LaneEntry.new(%{
                task_id: "light-1",
                image: "perme8-opencode-light",
                queue_position: 1,
                lane: :cold
              })
            ]
          },
          metadata: %{concurrency_limit: 2, running_count: 0}
        })

      assert {:ok, promoted} =
               PromoteTask.execute(snapshot,
                 task_repo: Agents.Sessions.Application.UseCases.PromoteTaskMockTaskRepo,
                 event_bus: Agents.Sessions.Application.UseCases.PromoteTaskMockEventBus
               )

      assert Enum.map(promoted, & &1.id) == ["light-1"]
    end
  end
end
