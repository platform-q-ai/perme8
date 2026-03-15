defmodule Agents.Sessions.Infrastructure.OrphanRecoveryTest do
  use Agents.DataCase

  alias Agents.Sessions.Infrastructure.OrphanRecovery
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo

  import Agents.Test.AccountsFixtures

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_task(user, attrs) do
    default = %{
      user_id: user.id,
      instruction: "test instruction"
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  defp reload_task(task) do
    Repo.get!(TaskSchema, task.id)
  end

  # Stub that records stop calls
  defmodule TrackingContainerProvider do
    @moduledoc false

    def stop(container_id, _opts \\ []) do
      send(Process.get(:test_pid), {:stopped, container_id})
      :ok
    end
  end

  # Stub that simulates stop failure
  defmodule FailingContainerProvider do
    @moduledoc false

    def stop(_container_id, _opts \\ []) do
      {:error, :not_found}
    end
  end

  # Stub that records both stop and remove calls
  defmodule StopAndRemoveTrackingContainerProvider do
    @moduledoc false

    def stop(container_id, _opts \\ []) do
      send(Process.get(:test_pid), {:stopped, container_id})
      :ok
    end

    def remove(container_id, _opts \\ []) do
      send(Process.get(:test_pid), {:removed, container_id})
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "recover_orphaned_tasks/1" do
    test "marks 'starting' tasks as failed" do
      user = user_fixture()
      task = insert_task(user, %{status: "starting", container_id: "abc123"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "failed"
      assert updated.error =~ "Orphaned"
      assert updated.completed_at != nil
    end

    test "marks 'pending' tasks as failed" do
      user = user_fixture()
      task = insert_task(user, %{status: "pending", container_id: "def456"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "failed"
      assert updated.error =~ "Orphaned"
    end

    test "marks 'running' tasks as failed" do
      user = user_fixture()
      task = insert_task(user, %{status: "running", container_id: "ghi789", session_id: "s1"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "failed"
      assert updated.error =~ "Orphaned"
    end

    test "stops containers for orphaned tasks" do
      user = user_fixture()
      _task = insert_task(user, %{status: "starting", container_id: "ctr-stop-me"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert_receive {:stopped, "ctr-stop-me"}
    end

    test "never calls remove on orphaned containers (only stop)" do
      user = user_fixture()

      _task =
        insert_task(user, %{status: "running", container_id: "ctr-orphan-1", session_id: "s1"})

      Process.put(:test_pid, self())

      OrphanRecovery.recover_orphaned_tasks(
        container_provider: StopAndRemoveTrackingContainerProvider
      )

      assert_receive {:stopped, "ctr-orphan-1"}
      refute_receive {:removed, "ctr-orphan-1"}
    end

    test "skips tasks without container_id (no container to stop)" do
      user = user_fixture()
      task = insert_task(user, %{status: "pending"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "failed"
      assert updated.error =~ "Orphaned"
      refute_receive {:stopped, _}
    end

    test "does not touch completed tasks" do
      user = user_fixture()
      task = insert_task(user, %{status: "completed", completed_at: DateTime.utc_now()})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "completed"
    end

    test "does not touch failed tasks" do
      user = user_fixture()
      task = insert_task(user, %{status: "failed", error: "something broke"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "failed"
      assert updated.error == "something broke"
    end

    test "does not touch queued tasks" do
      user = user_fixture()
      task = insert_task(user, %{status: "queued", queue_position: 1})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "queued"
    end

    test "handles container stop failure gracefully" do
      user = user_fixture()
      task = insert_task(user, %{status: "starting", container_id: "fail-me"})

      # Should not raise even when stop fails
      OrphanRecovery.recover_orphaned_tasks(container_provider: FailingContainerProvider)

      updated = reload_task(task)
      assert updated.status == "failed"
    end

    test "recovers multiple orphaned tasks" do
      user = user_fixture()
      t1 = insert_task(user, %{status: "starting", container_id: "c1"})
      t2 = insert_task(user, %{status: "running", container_id: "c2", session_id: "s2"})
      t3 = insert_task(user, %{status: "pending", container_id: "c3"})

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert reload_task(t1).status == "failed"
      assert reload_task(t2).status == "failed"
      assert reload_task(t3).status == "failed"

      assert_receive {:stopped, "c1"}
      assert_receive {:stopped, "c2"}
      assert_receive {:stopped, "c3"}
    end

    test "returns count of recovered tasks" do
      user = user_fixture()
      _t1 = insert_task(user, %{status: "starting", container_id: "c1"})
      _t2 = insert_task(user, %{status: "running", container_id: "c2", session_id: "s2"})

      Process.put(:test_pid, self())

      result =
        OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert result == {:ok, 2}
    end

    test "returns zero when nothing to recover" do
      result =
        OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert result == {:ok, 0}
    end
  end

  describe "PubSub broadcasting" do
    test "broadcasts per-task :task_status_changed for each orphan" do
      user = user_fixture()
      t1 = insert_task(user, %{status: "running", container_id: "c1", session_id: "s1"})
      t2 = insert_task(user, %{status: "starting", container_id: "c2"})

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{t1.id}")
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{t2.id}")

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert_receive {:task_status_changed, task1_id, "failed"}
      assert task1_id == t1.id

      assert_receive {:task_status_changed, task2_id, "failed"}
      assert task2_id == t2.id
    end

    test "broadcasts per-user :sessions_orphaned summary with correct count and task IDs" do
      user = user_fixture()
      t1 = insert_task(user, %{status: "running", container_id: "c1", session_id: "s1"})
      t2 = insert_task(user, %{status: "pending", container_id: "c2"})

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:user:#{user.id}")

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert_receive {:sessions_orphaned, count, task_ids}
      assert count == 2
      assert Enum.sort(task_ids) == Enum.sort([t1.id, t2.id])
    end

    test "groups broadcasts correctly for multiple users" do
      user_a = user_fixture()
      user_b = user_fixture()
      _t1 = insert_task(user_a, %{status: "running", container_id: "ca1", session_id: "s1"})
      _t2 = insert_task(user_a, %{status: "starting", container_id: "ca2"})
      _t3 = insert_task(user_b, %{status: "pending", container_id: "cb1"})

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:user:#{user_a.id}")
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:user:#{user_b.id}")

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      assert_receive {:sessions_orphaned, 2, _task_ids_a}
      assert_receive {:sessions_orphaned, 1, _task_ids_b}
    end

    test "does not broadcast when no orphans exist" do
      user = user_fixture()
      _completed = insert_task(user, %{status: "completed", completed_at: DateTime.utc_now()})

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:user:#{user.id}")

      Process.put(:test_pid, self())
      OrphanRecovery.recover_orphaned_tasks(container_provider: TrackingContainerProvider)

      refute_receive {:sessions_orphaned, _, _}
    end
  end
end
