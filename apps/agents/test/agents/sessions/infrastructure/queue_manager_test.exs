defmodule Agents.Sessions.Infrastructure.QueueManagerTest do
  use Agents.DataCase

  alias Agents.Sessions.Infrastructure.QueueManager
  alias Agents.Sessions.Infrastructure.QueueManagerSupervisor
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo
  alias Perme8.Events.TestEventBus

  import Agents.Test.AccountsFixtures

  # QueueRegistry and QueueManagerSupervisor are started by the OTP app supervision tree.

  defp create_task(user, attrs) do
    default_attrs = %{
      instruction: "Queue task",
      user_id: user.id,
      status: "pending"
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  describe "check_concurrency/1" do
    test "returns at_limit when running task count meets limit" do
      user = user_fixture()
      create_task(user, %{status: "pending"})
      create_task(user, %{status: "running"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert QueueManager.check_concurrency(user.id) == :at_limit
    end

    test "returns ok when below limit" do
      user = user_fixture()
      create_task(user, %{status: "running"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert QueueManager.check_concurrency(user.id) == :ok
    end
  end

  describe "get_queue_state/1" do
    test "returns running, queued, awaiting_feedback and concurrency limit" do
      user = user_fixture()
      create_task(user, %{status: "running"})
      queued = create_task(user, %{status: "queued", queue_position: 1})
      awaiting = create_task(user, %{status: "awaiting_feedback"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 3,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      state = QueueManager.get_queue_state(user.id)

      assert state.running == 1
      assert state.concurrency_limit == 3
      assert Enum.map(state.queued, & &1.id) == [queued.id]
      assert Enum.map(state.awaiting_feedback, & &1.id) == [awaiting.id]
    end
  end

  describe "notify_task_completed/2" do
    test "promotes next queued task and broadcasts queue update" do
      TestEventBus.start_global()

      user = user_fixture()
      queued = create_task(user, %{status: "queued", queue_position: 1})
      test_pid = self()

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 event_bus: TestEventBus,
                 pubsub: Perme8.Events.PubSub,
                 task_runner_starter: fn task_id, _opts ->
                   send(test_pid, {:started_runner, task_id})
                   {:ok, self()}
                 end
               )

      QueueManager.notify_task_completed(user.id, queued.id)

      queued_id = queued.id
      user_id = user.id

      assert_receive {:started_runner, ^queued_id}
      assert_receive {:queue_updated, ^user_id, _queue_state}

      updated = Repo.get!(TaskSchema, queued.id)
      assert updated.status == "pending"
      assert updated.queue_position == nil
    end
  end

  describe "set_concurrency_limit/2" do
    test "updates limit and triggers promotion when capacity is available" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})
      queued = create_task(user, %{status: "queued", queue_position: 1})
      test_pid = self()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 task_runner_starter: fn task_id, _opts ->
                   send(test_pid, {:started_runner, task_id})
                   {:ok, self()}
                 end
               )

      assert QueueManager.get_concurrency_limit(user.id) == 1

      assert :ok = QueueManager.set_concurrency_limit(user.id, 2)
      assert QueueManager.get_concurrency_limit(user.id) == 2

      queued_id = queued.id
      assert_receive {:started_runner, ^queued_id}
    end
  end
end
