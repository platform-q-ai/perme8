defmodule Agents.Sessions.Application.UseCases.BuildSnapshotMockTaskRepo do
  def list_tasks_for_user(user_id, opts) do
    send(self(), {:list_tasks_for_user, user_id, opts})
    Process.get(:active_tasks, [])
  end

  def list_awaiting_feedback_tasks(user_id) do
    send(self(), {:list_awaiting_feedback_tasks, user_id})
    Process.get(:awaiting_tasks, [])
  end
end

defmodule Agents.Sessions.Application.UseCases.BuildSnapshotTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Application.UseCases.BuildSnapshot
  alias Agents.Sessions.Domain.Entities.QueueSnapshot

  describe "execute/2" do
    test "builds snapshot from tasks loaded via repo" do
      Process.put(:active_tasks, [
        %{
          id: "running-1",
          instruction: "Active task",
          status: "running",
          started_at: ~U[2026-01-01 00:00:00Z]
        },
        %{
          id: "queued-1",
          instruction: "Queued task",
          status: "queued",
          queue_position: 1
        }
      ])

      Process.put(:awaiting_tasks, [
        %{id: "feedback-1", instruction: "Need answer", status: "awaiting_feedback"}
      ])

      assert {:ok, %QueueSnapshot{} = snapshot} =
               BuildSnapshot.execute("user-1",
                 task_repo: Agents.Sessions.Application.UseCases.BuildSnapshotMockTaskRepo
               )

      assert_receive {:list_tasks_for_user, "user-1", [status: :active]}
      assert_receive {:list_awaiting_feedback_tasks, "user-1"}
      assert Enum.map(snapshot.lanes.processing, & &1.task_id) == ["running-1"]
      assert Enum.map(snapshot.lanes.cold, & &1.task_id) == ["queued-1"]
      assert Enum.map(snapshot.lanes.awaiting_feedback, & &1.task_id) == ["feedback-1"]
    end

    test "handles empty task list" do
      Process.put(:active_tasks, [])
      Process.put(:awaiting_tasks, [])

      assert {:ok, %QueueSnapshot{} = snapshot} =
               BuildSnapshot.execute("user-1",
                 task_repo: Agents.Sessions.Application.UseCases.BuildSnapshotMockTaskRepo
               )

      assert snapshot.lanes.processing == []
      assert snapshot.lanes.cold == []
      assert snapshot.lanes.awaiting_feedback == []
      assert snapshot.lanes.retry_pending == []
      assert snapshot.metadata.total_queued == 0
    end

    test "populates metadata from config defaults" do
      Process.put(:active_tasks, [
        %{
          id: "running-1",
          instruction: "Active task",
          status: "running",
          started_at: ~U[2026-01-01 00:00:00Z]
        }
      ])

      Process.put(:awaiting_tasks, [])

      assert {:ok, %QueueSnapshot{} = snapshot} =
               BuildSnapshot.execute("user-1",
                 task_repo: Agents.Sessions.Application.UseCases.BuildSnapshotMockTaskRepo
               )

      assert snapshot.metadata.concurrency_limit == 2
      assert snapshot.metadata.running_count == 1
      assert snapshot.metadata.available_slots == 1
    end
  end
end
