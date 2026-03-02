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

  describe "notify_task_failed/2" do
    test "promotes next queued task when a task fails" do
      user = user_fixture()
      queued = create_task(user, %{status: "queued", queue_position: 1})
      test_pid = self()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn task_id, _opts ->
                   send(test_pid, {:started_runner, task_id})
                   {:ok, self()}
                 end
               )

      QueueManager.notify_task_failed(user.id, "some-failed-task-id")

      queued_id = queued.id
      assert_receive {:started_runner, ^queued_id}

      updated = Repo.get!(TaskSchema, queued.id)
      assert updated.status == "pending"
    end
  end

  describe "notify_task_cancelled/2" do
    test "promotes next queued task when a task is cancelled" do
      user = user_fixture()
      queued = create_task(user, %{status: "queued", queue_position: 1})
      test_pid = self()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn task_id, _opts ->
                   send(test_pid, {:started_runner, task_id})
                   {:ok, self()}
                 end
               )

      QueueManager.notify_task_cancelled(user.id, "some-cancelled-task-id")

      queued_id = queued.id
      assert_receive {:started_runner, ^queued_id}

      updated = Repo.get!(TaskSchema, queued.id)
      assert updated.status == "pending"
    end
  end

  describe "notify_question_asked/2" do
    test "moves running task to awaiting_feedback and promotes next queued task" do
      user = user_fixture()
      running = create_task(user, %{status: "running"})
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

      QueueManager.notify_question_asked(user.id, running.id)

      updated_running = Repo.get!(TaskSchema, running.id)
      assert updated_running.status == "awaiting_feedback"

      queued_id = queued.id
      assert_receive {:started_runner, ^queued_id}
    end

    test "does not deprioritise completed tasks" do
      user = user_fixture()
      completed = create_task(user, %{status: "completed"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      QueueManager.notify_question_asked(user.id, completed.id)

      updated = Repo.get!(TaskSchema, completed.id)
      assert updated.status == "completed"
    end
  end

  describe "notify_feedback_provided/2" do
    test "requeues awaiting_feedback task and promotes if capacity available" do
      user = user_fixture()
      awaiting = create_task(user, %{status: "awaiting_feedback"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      QueueManager.notify_feedback_provided(user.id, awaiting.id)

      updated = Repo.get!(TaskSchema, awaiting.id)
      # Task is requeued then immediately promoted since under limit
      assert updated.status == "pending"
    end

    test "does not requeue tasks not in awaiting_feedback status" do
      user = user_fixture()
      running = create_task(user, %{status: "running"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      QueueManager.notify_feedback_provided(user.id, running.id)

      updated = Repo.get!(TaskSchema, running.id)
      assert updated.status == "running"
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
