defmodule Agents.Sessions.Infrastructure.QueueOrchestratorTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Infrastructure.QueueOrchestrator
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  import Agents.Test.AccountsFixtures

  defp create_task(user, attrs) do
    default_attrs = %{
      instruction: "Queue task",
      user_id: user.id,
      status: "pending",
      container_id: nil
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
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

      assert {:error, :invalid_limit} = QueueOrchestrator.set_concurrency_limit(user.id, 0)
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
end
