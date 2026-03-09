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
      status: "pending",
      container_id: nil
    }

    attrs = maybe_put_warm_container_id(attrs)

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp maybe_put_warm_container_id(attrs) do
    status = attrs[:status] || attrs["status"]
    has_container_id = Map.has_key?(attrs, :container_id) or Map.has_key?(attrs, "container_id")

    if status == "queued" and not has_container_id do
      Map.put(attrs, :container_id, "warm-#{System.unique_integer([:positive])}")
    else
      attrs
    end
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

    test "returns warm_task_ids from top queued positions up to warm cache limit" do
      user = user_fixture()

      first = create_task(user, %{status: "queued", queue_position: 1})
      second = create_task(user, %{status: "queued", queue_position: 2})
      _third = create_task(user, %{status: "queued", queue_position: 3})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 warm_cache_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      state = QueueManager.get_queue_state(user.id)

      assert state.warm_cache_limit == 2
      assert state.warm_task_ids == [first.id, second.id]
    end
  end

  describe "queue processor rules" do
    test "does not promote cold queued tasks before warm readiness" do
      user = user_fixture()

      cold = create_task(user, %{status: "queued", queue_position: 1, container_id: nil})

      {:module, container_provider_mod, _, _} =
        defmodule :"Agents.Sessions.QueueManagerTest.NoopContainerProvider.#{System.unique_integer([:positive])}" do
          def start(_image, _opts), do: {:error, :warmup_disabled}
          def stop(_container_id, _opts \\ []), do: :ok
          def status(_container_id, _opts \\ []), do: {:ok, :not_found}
          def remove(_container_id, _opts \\ []), do: :ok
          def restart(_container_id, _opts \\ []), do: {:ok, %{port: 4096}}

          def stats(_container_id, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}

          def prepare_fresh_start(_container_id, _opts \\ []), do: :ok
        end

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 warm_cache_limit: 0,
                 container_provider: container_provider_mod,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert :ok = QueueManager.notify_task_queued(user.id, cold.id)

      updated = Repo.get!(TaskSchema, cold.id)
      assert updated.status == "queued"
      assert updated.queue_position == 1
    end

    test "promotes queued tasks up to concurrency limit in queue order" do
      user = user_fixture()

      first = create_task(user, %{status: "queued", queue_position: 1})
      second = create_task(user, %{status: "queued", queue_position: 2})
      third = create_task(user, %{status: "queued", queue_position: 3})

      test_pid = self()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn task_id, _opts ->
                   send(test_pid, {:started_runner, task_id})
                   {:ok, self()}
                 end
               )

      assert :ok = QueueManager.notify_task_queued(user.id, first.id)

      first_id = first.id
      second_id = second.id
      third_id = third.id

      assert_receive {:started_runner, ^first_id}
      assert_receive {:started_runner, ^second_id}
      refute_receive {:started_runner, ^third_id}, 100

      assert Repo.get!(TaskSchema, first.id).status == "pending"
      assert Repo.get!(TaskSchema, second.id).status == "pending"
      assert Repo.get!(TaskSchema, third.id).status == "queued"
    end

    test "promotion clears stale lifecycle timestamps from previously completed task" do
      user = user_fixture()

      queued =
        create_task(user, %{status: "queued", queue_position: 1})
        |> TaskSchema.status_changeset(%{
          started_at: ~U[2026-03-01 00:00:00Z],
          completed_at: ~U[2026-03-01 00:10:00Z],
          error: "old error"
        })
        |> Repo.update!()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert :ok = QueueManager.notify_task_queued(user.id, queued.id)

      updated = Repo.get!(TaskSchema, queued.id)
      assert updated.status == "pending"
      assert is_nil(updated.started_at)
      assert is_nil(updated.completed_at)
      assert is_nil(updated.error)
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

    test "broadcasts lifecycle_state_changed when promoting queued task" do
      user = user_fixture()

      queued =
        create_task(user, %{status: "queued", queue_position: 1, container_id: "warm-container"})

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{queued.id}")

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 warm_cache_limit: 0,
                 pubsub: Perme8.Events.PubSub,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      QueueManager.notify_task_completed(user.id, queued.id)

      queued_id = queued.id
      assert_receive {:lifecycle_state_changed, ^queued_id, :queued_warm, :warming}
    end

    test "promotes queued resume tasks with resume runner opts" do
      user = user_fixture()

      queued_resume =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "resume-container",
          session_id: "resume-session",
          instruction: "Original task instruction"
        })

      queued_resume =
        queued_resume
        |> TaskSchema.status_changeset(%{
          pending_question: %{"resume_prompt" => "Follow-up prompt"}
        })
        |> Repo.update!()

      test_pid = self()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn task_id, opts ->
                   send(test_pid, {:started_runner, task_id, opts})
                   {:ok, self()}
                 end
               )

      QueueManager.notify_task_completed(user.id, queued_resume.id)

      queued_id = queued_resume.id
      assert_receive {:started_runner, ^queued_id, opts}
      assert opts[:resume] == true
      assert opts[:prompt_instruction] == "Follow-up prompt"
      assert opts[:container_id] == "resume-container"
      assert opts[:session_id] == "resume-session"

      updated = Repo.get!(TaskSchema, queued_resume.id)
      assert updated.status == "pending"
      assert updated.pending_question == nil
    end
  end

  describe "notify_task_queued/2" do
    test "warms only top queued cold tasks and skips already exited containers" do
      user = user_fixture()
      _running1 = create_task(user, %{status: "running"})
      _running2 = create_task(user, %{status: "running"})
      _running3 = create_task(user, %{status: "running"})

      first = create_task(user, %{status: "queued", queue_position: 1, container_id: nil})

      _second =
        create_task(user, %{status: "queued", queue_position: 2, container_id: "exited-2"})

      third = create_task(user, %{status: "queued", queue_position: 3, container_id: nil})

      test_pid = self()

      {:module, container_provider_mod, _, _} =
        defmodule :"Agents.Sessions.QueueManagerTest.MockContainerProvider.#{System.unique_integer([:positive])}" do
          def set_test_pid(pid), do: :persistent_term.put({__MODULE__, :test_pid}, pid)

          def start(_image, _opts) do
            send(:persistent_term.get({__MODULE__, :test_pid}), :container_started)
            {:ok, %{container_id: "warmed-1", port: 4096}}
          end

          def stop(container_id, _opts \\ []) do
            send(
              :persistent_term.get({__MODULE__, :test_pid}),
              {:container_stopped, container_id}
            )

            :ok
          end

          def status(container_id, _opts \\ [])
          def status("exited-2", _opts), do: {:ok, :stopped}
          def status(_container_id, _opts), do: {:ok, :not_found}

          def remove(_container_id, _opts \\ []), do: :ok
          def restart(_container_id, _opts \\ []), do: {:ok, %{port: 4096}}

          def stats(_container_id, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}
        end

      container_provider_mod.set_test_pid(test_pid)

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 3,
                 container_provider: container_provider_mod,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert :ok = QueueManager.notify_task_queued(user.id, first.id)

      assert_receive :container_started
      assert_receive {:container_stopped, "warmed-1"}

      updated_first = Repo.get!(TaskSchema, first.id)
      updated_third = Repo.get!(TaskSchema, third.id)

      assert updated_first.container_id == "warmed-1"
      assert is_nil(updated_third.container_id)
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
      awaiting = create_task(user, %{status: "awaiting_feedback", container_id: "warm-feedback"})

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

    test "enforce_concurrency_limit requeues excess running tasks when limit is lowered" do
      TestEventBus.start_global()

      user = user_fixture()
      running1 = create_task(user, %{status: "running"})
      running2 = create_task(user, %{status: "running"})
      running3 = create_task(user, %{status: "running"})

      {:module, noop_container_mod, _, _} =
        defmodule :"Agents.Sessions.QueueManagerTest.NoopContainerForEnforce.#{System.unique_integer([:positive])}" do
          def start(_image, _opts), do: {:error, :warmup_disabled}
          def stop(_container_id, _opts \\ []), do: :ok
          def status(_container_id, _opts \\ []), do: {:ok, :not_found}
          def remove(_container_id, _opts \\ []), do: :ok
          def restart(_container_id, _opts \\ []), do: {:ok, %{port: 4096}}

          def stats(_container_id, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}

          def prepare_fresh_start(_container_id, _opts \\ []), do: :ok
        end

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 3,
                 event_bus: TestEventBus,
                 pubsub: Perme8.Events.PubSub,
                 container_provider: noop_container_mod,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      # Lower limit from 3 to 1 — should requeue 2 youngest active tasks
      assert :ok = QueueManager.set_concurrency_limit(user.id, 1)
      assert QueueManager.get_concurrency_limit(user.id) == 1

      assert_receive {:queue_updated, _, _queue_state}

      # Check that exactly 2 tasks were requeued (the youngest two)
      tasks =
        [running1.id, running2.id, running3.id]
        |> Enum.map(&Repo.get!(TaskSchema, &1))

      queued_tasks = Enum.filter(tasks, &(&1.status == "queued"))
      active_tasks = Enum.filter(tasks, &(&1.status in ["running", "pending", "starting"]))

      # 2 should be requeued, 1 should remain active
      assert length(queued_tasks) == 2
      assert length(active_tasks) == 1
    end

    test "enforce_concurrency_limit is a no-op when within limit" do
      user = user_fixture()
      running = create_task(user, %{status: "running"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 2,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      # Raise limit — nothing should be requeued
      assert :ok = QueueManager.set_concurrency_limit(user.id, 3)

      updated = Repo.get!(TaskSchema, running.id)
      assert updated.status == "running"
    end
  end

  describe "light image queue bypass" do
    test "light image tasks don't count against concurrency limit" do
      user = user_fixture()
      create_task(user, %{status: "running", image: "perme8-opencode-light"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert QueueManager.check_concurrency(user.id) == :ok
    end

    test "light image queued tasks are promoted immediately even when at heavyweight limit" do
      user = user_fixture()
      create_task(user, %{status: "running", image: "perme8-opencode"})

      light_queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          image: "perme8-opencode-light"
        })

      test_pid = self()

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 task_runner_starter: fn task_id, _opts ->
                   send(test_pid, {:started_runner, task_id})
                   {:ok, self()}
                 end
               )

      assert :ok = QueueManager.notify_task_queued(user.id, light_queued.id)

      light_id = light_queued.id
      assert_receive {:started_runner, ^light_id}

      updated = Repo.get!(TaskSchema, light_queued.id)
      assert updated.status == "pending"
    end

    test "heavyweight tasks remain queued when at limit with light tasks running" do
      user = user_fixture()
      create_task(user, %{status: "running", image: "perme8-opencode"})
      create_task(user, %{status: "running", image: "perme8-opencode-light"})

      heavy_queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          image: "perme8-opencode"
        })

      {:module, noop_container_mod, _, _} =
        defmodule :"Agents.Sessions.QueueManagerTest.NoopForLightTest.#{System.unique_integer([:positive])}" do
          def start(_image, _opts), do: {:error, :warmup_disabled}
          def stop(_container_id, _opts \\ []), do: :ok
          def status(_container_id, _opts \\ []), do: {:ok, :not_found}
          def remove(_container_id, _opts \\ []), do: :ok
          def restart(_container_id, _opts \\ []), do: {:ok, %{port: 4096}}

          def stats(_container_id, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}

          def prepare_fresh_start(_container_id, _opts \\ []), do: :ok
        end

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 container_provider: noop_container_mod,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert :ok = QueueManager.notify_task_queued(user.id, heavy_queued.id)

      updated = Repo.get!(TaskSchema, heavy_queued.id)
      assert updated.status == "queued"
    end

    test "multiple light image tasks can run simultaneously" do
      user = user_fixture()
      create_task(user, %{status: "running", image: "perme8-opencode-light"})
      create_task(user, %{status: "running", image: "perme8-opencode-light"})

      assert {:ok, _pid} =
               QueueManagerSupervisor.ensure_started(user.id,
                 concurrency_limit: 1,
                 task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
               )

      assert QueueManager.check_concurrency(user.id) == :ok
    end
  end
end
