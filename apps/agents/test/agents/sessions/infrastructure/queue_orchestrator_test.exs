defmodule Agents.Sessions.Infrastructure.QueueOrchestratorTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Infrastructure.QueueOrchestrator
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  import Agents.Test.AccountsFixtures

  # Fields that require status_changeset (not in the creation changeset)
  @status_only_fields [:pending_question, :todo_items, :session_summary]

  defp create_task(user, attrs) do
    {status_attrs, create_attrs} = Map.split(attrs, @status_only_fields)

    default_attrs = %{
      instruction: "Queue task",
      user_id: user.id,
      status: "pending",
      container_id: nil
    }

    task =
      %TaskSchema{}
      |> TaskSchema.changeset(Map.merge(default_attrs, create_attrs))
      |> Repo.insert!()

    if map_size(status_attrs) > 0 do
      task
      |> TaskSchema.status_changeset(status_attrs)
      |> Repo.update!()
    else
      task
    end
  end

  defp start_orchestrator!(user_id, opts \\ []) do
    start_supervised!({QueueOrchestrator, Keyword.put(opts, :user_id, user_id)})
  end

  describe "get_snapshot/1" do
    test "returns a QueueSnapshot with expected lane assignments" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      _warm =
        create_task(user, %{status: "queued", queue_position: 1, container_id: "container-1"})

      _cold = create_task(user, %{status: "queued", queue_position: 2, container_id: nil})
      _retry = create_task(user, %{status: "queued", queue_position: 3, retry_count: 1})
      _awaiting = create_task(user, %{status: "awaiting_feedback"})

      start_orchestrator!(user.id, concurrency_limit: 3)

      snapshot = QueueOrchestrator.get_snapshot(user.id)

      assert %QueueSnapshot{} = snapshot
      assert length(snapshot.lanes.processing) == 1
      assert length(snapshot.lanes.warm) == 1
      assert length(snapshot.lanes.cold) == 1
      assert length(snapshot.lanes.retry_pending) == 1
      assert length(snapshot.lanes.awaiting_feedback) == 1
    end
  end

  describe "notify_task_completed/2" do
    test "promotes next queued task and broadcasts queue snapshot" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      queued =
        create_task(user, %{status: "queued", queue_position: 1, container_id: "container-1"})

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{queued.id}")

      start_orchestrator!(user.id,
        concurrency_limit: 2,
        pubsub: Perme8.Events.PubSub,
        task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
      )

      assert :ok = QueueOrchestrator.notify_task_completed(user.id, queued.id)

      user_id = user.id
      queued_id = queued.id
      assert_receive {:queue_snapshot, ^user_id, %QueueSnapshot{}}
      assert_receive {:lifecycle_state_changed, ^queued_id, :queued_warm, :warming}

      updated = Repo.get!(TaskSchema, queued.id)
      assert updated.status == "pending"
      assert is_nil(updated.queue_position)
    end
  end

  describe "notify_task_failed/2" do
    test "schedules retry when failure is retryable" do
      user = user_fixture()

      failed =
        create_task(user, %{
          status: "failed",
          error: "runner_start_failed",
          retry_count: 0,
          queue_position: 1
        })

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

      start_orchestrator!(user.id, pubsub: Perme8.Events.PubSub)

      assert :ok = QueueOrchestrator.notify_task_failed(user.id, failed.id)

      user_id = user.id
      assert_receive {:queue_snapshot, ^user_id, %QueueSnapshot{}}

      updated = Repo.get!(TaskSchema, failed.id)
      assert updated.status == "queued"
      assert updated.retry_count == 1
      assert %DateTime{} = updated.last_retry_at
      assert %DateTime{} = updated.next_retry_at
    end

    test "does not schedule retry for non-retryable failures" do
      user = user_fixture()

      failed =
        create_task(user, %{
          status: "failed",
          error: "validation_error",
          retry_count: 0
        })

      start_orchestrator!(user.id)

      assert :ok = QueueOrchestrator.notify_task_failed(user.id, failed.id)

      updated = Repo.get!(TaskSchema, failed.id)
      assert updated.status == "failed"
      assert updated.retry_count == 0
      assert is_nil(updated.last_retry_at)
      assert is_nil(updated.next_retry_at)
    end
  end

  describe "set_concurrency_limit/2" do
    test "accepts valid limits and broadcasts snapshot" do
      user = user_fixture()
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

      start_orchestrator!(user.id, pubsub: Perme8.Events.PubSub)

      assert :ok = QueueOrchestrator.set_concurrency_limit(user.id, 3)

      user_id = user.id
      assert_receive {:queue_snapshot, ^user_id, %QueueSnapshot{} = snapshot}
      assert snapshot.metadata.concurrency_limit == 3
    end

    test "rejects invalid limits" do
      user = user_fixture()
      start_orchestrator!(user.id)

      assert {:error, :invalid_limit} = QueueOrchestrator.set_concurrency_limit(user.id, -1)
      assert {:error, :invalid_limit} = QueueOrchestrator.set_concurrency_limit(user.id, 99)
    end
  end

  describe "check_concurrency/1" do
    test "returns at_limit when processing lane fills available slots" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      start_orchestrator!(user.id, concurrency_limit: 1)

      assert :at_limit = QueueOrchestrator.check_concurrency(user.id)
    end

    test "returns ok when slots are available" do
      user = user_fixture()
      start_orchestrator!(user.id, concurrency_limit: 1)

      assert :ok = QueueOrchestrator.check_concurrency(user.id)
    end

    test "returns ok when only light image tasks are running" do
      user = user_fixture()

      _light_running =
        create_task(user, %{status: "running", image: "perme8-opencode-light"})

      start_orchestrator!(user.id, concurrency_limit: 1)

      # Light image tasks don't count toward concurrency
      assert :ok = QueueOrchestrator.check_concurrency(user.id)
    end
  end

  describe "light image promotion" do
    test "promotes light image tasks even when at concurrency limit" do
      user = user_fixture()
      _heavy_running = create_task(user, %{status: "running", image: "perme8-opencode"})

      light_queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          image: "perme8-opencode-light"
        })

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        pubsub: Perme8.Events.PubSub,
        task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
      )

      assert :ok = QueueOrchestrator.notify_task_queued(user.id, light_queued.id)

      updated = Repo.get!(TaskSchema, light_queued.id)
      assert updated.status == "pending"
    end

    test "does not promote heavyweight tasks when at concurrency limit" do
      user = user_fixture()
      _heavy_running = create_task(user, %{status: "running", image: "perme8-opencode"})

      heavy_queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          image: "perme8-opencode"
        })

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        pubsub: Perme8.Events.PubSub,
        task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
      )

      assert :ok = QueueOrchestrator.notify_task_queued(user.id, heavy_queued.id)

      updated = Repo.get!(TaskSchema, heavy_queued.id)
      assert updated.status == "queued"
    end

    test "snapshot running_count excludes light image tasks" do
      user = user_fixture()
      _heavy_running = create_task(user, %{status: "running", image: "perme8-opencode"})
      _light_running = create_task(user, %{status: "running", image: "perme8-opencode-light"})

      start_orchestrator!(user.id, concurrency_limit: 2)

      snapshot = QueueOrchestrator.get_snapshot(user.id)

      # Only the heavyweight task counts
      assert snapshot.metadata.running_count == 1
      assert snapshot.metadata.available_slots == 1
      # Both tasks are in the processing lane
      assert length(snapshot.lanes.processing) == 2
    end
  end

  describe "promote_single_task resume_prompt and runner opts" do
    test "extracts resume_prompt from pending_question and passes resume opts to runner" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "cid-1",
          session_id: "sid-1",
          instruction: "do something",
          pending_question: %{"resume_prompt" => "continue here", "other_key" => "keep"}
        })

      test_pid = self()

      runner_starter = fn task_id, opts ->
        send(test_pid, {:runner_started, task_id, opts})
        {:ok, self()}
      end

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        task_runner_starter: runner_starter
      )

      assert :ok = QueueOrchestrator.notify_task_completed(user.id, queued.id)

      assert_receive {:runner_started, task_id, opts}
      assert task_id == queued.id
      assert opts[:resume] == true
      assert opts[:prompt_instruction] == "continue here"
      assert opts[:container_id] == "cid-1"
      assert opts[:session_id] == "sid-1"
      assert opts[:instruction] == "do something"

      updated = Repo.get!(TaskSchema, queued.id)
      assert updated.pending_question == %{"other_key" => "keep"}
    end

    test "passes prewarmed opts with already_healthy when task has container_id and port" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "warm-cid",
          container_port: 4001,
          session_id: nil
        })

      test_pid = self()

      runner_starter = fn task_id, opts ->
        send(test_pid, {:runner_started, task_id, opts})
        {:ok, self()}
      end

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        task_runner_starter: runner_starter
      )

      assert :ok = QueueOrchestrator.notify_task_completed(user.id, queued.id)

      assert_receive {:runner_started, _task_id, opts}
      assert opts[:prewarmed_container_id] == "warm-cid"
      assert opts[:container_port] == 4001
      assert opts[:already_healthy] == true
      assert opts[:fresh_warm_container] == true
      refute opts[:resume]
    end

    test "passes prewarmed opts without already_healthy when task has container_id but no port" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "warm-cid",
          session_id: nil
        })

      test_pid = self()

      runner_starter = fn task_id, opts ->
        send(test_pid, {:runner_started, task_id, opts})
        {:ok, self()}
      end

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        task_runner_starter: runner_starter
      )

      assert :ok = QueueOrchestrator.notify_task_completed(user.id, queued.id)

      assert_receive {:runner_started, _task_id, opts}
      assert opts[:prewarmed_container_id] == "warm-cid"
      assert opts[:fresh_warm_container] == true
      refute opts[:already_healthy]
      refute opts[:resume]
    end

    test "passes empty opts for cold start task" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: nil,
          session_id: nil
        })

      test_pid = self()

      runner_starter = fn task_id, opts ->
        send(test_pid, {:runner_started, task_id, opts})
        {:ok, self()}
      end

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        task_runner_starter: runner_starter
      )

      assert :ok = QueueOrchestrator.notify_task_completed(user.id, queued.id)

      assert_receive {:runner_started, _task_id, opts}
      assert opts == []
    end

    test "clears resume_prompt entirely when no other keys in pending_question" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      queued =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "cid-2",
          session_id: "sid-2",
          instruction: "work",
          pending_question: %{"resume_prompt" => "try again"}
        })

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
      )

      assert :ok = QueueOrchestrator.notify_task_completed(user.id, queued.id)

      updated = Repo.get!(TaskSchema, queued.id)
      assert is_nil(updated.pending_question)
    end
  end

  describe "warm_top_queued handler" do
    test "starts containers for cold queued tasks up to warm_cache_limit" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      cold1 =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: nil
        })

      cold2 =
        create_task(user, %{
          status: "queued",
          queue_position: 2,
          container_id: nil
        })

      cold3 =
        create_task(user, %{
          status: "queued",
          queue_position: 3,
          container_id: nil
        })

      test_pid = self()
      call_counter = :counters.new(1, [:atomics])

      container_provider =
        Agents.Test.StubContainerProvider.new(%{
          start: fn _image, _opts ->
            :counters.add(call_counter, 1, 1)
            count = :counters.get(call_counter, 1)
            send(test_pid, {:container_started, count})
            {:ok, %{container_id: "warm-#{count}", port: 4000 + count}}
          end,
          status: fn _id -> {:ok, :running} end
        })

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        warm_cache_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        container_provider: container_provider
      )

      # Trigger warming by notifying a task was queued
      assert :ok = QueueOrchestrator.notify_task_queued(user.id, cold1.id)

      # Wait for async warming to complete
      assert_receive {:container_started, _}, 5_000
      assert_receive {:container_started, _}, 5_000

      # Give time for the DB updates from the async warming handler
      Process.sleep(100)

      # First 2 tasks should be warmed (container_id and container_port set)
      updated1 = Repo.get!(TaskSchema, cold1.id)
      updated2 = Repo.get!(TaskSchema, cold2.id)
      updated3 = Repo.get!(TaskSchema, cold3.id)

      assert is_binary(updated1.container_id)
      assert is_integer(updated1.container_port)
      assert is_binary(updated2.container_id)
      assert is_integer(updated2.container_port)

      # Third task should remain cold
      assert is_nil(updated3.container_id)
      assert is_nil(updated3.container_port)
    end

    test "skips tasks that already have a running container" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      warm_task =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "existing-cid",
          container_port: 4001
        })

      test_pid = self()

      container_provider =
        Agents.Test.StubContainerProvider.new(%{
          start: fn _image, _opts ->
            send(test_pid, :container_started)
            {:ok, %{container_id: "new-cid", port: 5000}}
          end,
          status: fn "existing-cid" -> {:ok, :running} end
        })

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        warm_cache_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        container_provider: container_provider
      )

      assert :ok = QueueOrchestrator.notify_task_queued(user.id, warm_task.id)

      # Wait a bit to make sure no container start was triggered
      Process.sleep(200)
      refute_receive :container_started

      # Task should still have original container
      updated = Repo.get!(TaskSchema, warm_task.id)
      assert updated.container_id == "existing-cid"
      assert updated.container_port == 4001
    end

    test "re-warms tasks whose container is not_found" do
      user = user_fixture()
      _running = create_task(user, %{status: "running"})

      stale_task =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: "gone-cid",
          container_port: nil
        })

      test_pid = self()

      container_provider =
        Agents.Test.StubContainerProvider.new(%{
          start: fn _image, _opts ->
            send(test_pid, :container_started)
            {:ok, %{container_id: "new-warm-cid", port: 5001}}
          end,
          status: fn "gone-cid" -> {:ok, :not_found} end
        })

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        warm_cache_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        container_provider: container_provider
      )

      assert :ok = QueueOrchestrator.notify_task_queued(user.id, stale_task.id)

      assert_receive :container_started, 5_000
      Process.sleep(100)

      updated = Repo.get!(TaskSchema, stale_task.id)
      assert updated.container_id == "new-warm-cid"
      assert updated.container_port == 5001
    end

    test "does nothing when warm_cache_limit is 0" do
      user = user_fixture()

      cold =
        create_task(user, %{
          status: "queued",
          queue_position: 1,
          container_id: nil
        })

      test_pid = self()

      container_provider =
        Agents.Test.StubContainerProvider.new(%{
          start: fn _image, _opts ->
            send(test_pid, :container_started)
            {:ok, %{container_id: "cid", port: 4000}}
          end,
          status: fn _id -> {:ok, :not_found} end
        })

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        warm_cache_limit: 0,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        container_provider: container_provider
      )

      assert :ok = QueueOrchestrator.notify_task_queued(user.id, cold.id)

      Process.sleep(200)
      refute_receive :container_started

      updated = Repo.get!(TaskSchema, cold.id)
      assert is_nil(updated.container_id)
    end
  end

  describe "re-queued tasks with existing containers" do
    test "stops container when task with container_id is re-queued via feedback" do
      user = user_fixture()
      # Occupy the concurrency slot so the re-queued task stays queued
      _running = create_task(user, %{status: "running"})

      af_task =
        create_task(user, %{
          status: "awaiting_feedback",
          container_id: "old-cid",
          session_id: "old-sid"
        })

      test_pid = self()

      container_provider =
        Agents.Test.StubContainerProvider.new(%{
          stop: fn container_id ->
            send(test_pid, {:container_stopped, container_id})
            :ok
          end,
          status: fn _id -> {:ok, :running} end,
          start: fn _image, _opts ->
            {:ok, %{container_id: "new-cid", port: 5000}}
          end
        })

      Perme8.Events.TestEventBus.start_global()

      start_orchestrator!(user.id,
        concurrency_limit: 1,
        warm_cache_limit: 2,
        pubsub: Perme8.Events.PubSub,
        event_bus: Perme8.Events.TestEventBus,
        container_provider: container_provider
      )

      assert :ok = QueueOrchestrator.notify_feedback_provided(user.id, af_task.id)

      assert_receive {:container_stopped, "old-cid"}, 5_000

      # Task should be re-queued with container_port cleared
      updated = Repo.get!(TaskSchema, af_task.id)
      assert updated.status == "queued"
      assert is_nil(updated.container_port)
    end
  end
end
