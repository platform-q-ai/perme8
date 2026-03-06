defmodule Agents.Sessions.Infrastructure.QueueOrchestrator do
  @moduledoc """
  Per-user queue orchestrator. Single source of truth for queue state,
  delegating policy decisions to QueueEngine and RetryPolicy.
  """

  use GenServer

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Events.{TaskLaneChanged, TaskPromoted, TaskRetryScheduled}
  alias Agents.Sessions.Domain.Policies.{QueueEngine, QueuePolicy, RetryPolicy}
  alias Agents.Sessions.Infrastructure.Adapters.DockerAdapter
  alias Agents.Sessions.Infrastructure.Repositories.TaskRepository

  require Logger

  def start_link(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(user_id))
  end

  def get_snapshot(user_id), do: GenServer.call(via_tuple(user_id), :get_snapshot)
  def check_concurrency(user_id), do: GenServer.call(via_tuple(user_id), :check_concurrency)

  def notify_task_queued(user_id, task_id),
    do: GenServer.call(via_tuple(user_id), {:notify_task_queued, task_id})

  def notify_task_completed(user_id, task_id),
    do: GenServer.call(via_tuple(user_id), {:notify_task_completed, task_id})

  def notify_task_failed(user_id, task_id),
    do: GenServer.call(via_tuple(user_id), {:notify_task_failed, task_id})

  def notify_task_cancelled(user_id, task_id),
    do: GenServer.call(via_tuple(user_id), {:notify_task_cancelled, task_id})

  def notify_question_asked(user_id, task_id),
    do: GenServer.call(via_tuple(user_id), {:notify_question_asked, task_id})

  def notify_feedback_provided(user_id, task_id),
    do: GenServer.call(via_tuple(user_id), {:notify_feedback_provided, task_id})

  def set_concurrency_limit(user_id, limit),
    do: GenServer.call(via_tuple(user_id), {:set_concurrency_limit, limit})

  def set_warm_cache_limit(user_id, limit),
    do: GenServer.call(via_tuple(user_id), {:set_warm_cache_limit, limit})

  def get_queue_state(user_id), do: GenServer.call(via_tuple(user_id), :get_queue_state)

  def get_concurrency_limit(user_id),
    do: GenServer.call(via_tuple(user_id), :get_concurrency_limit)

  def get_warm_cache_limit(user_id), do: GenServer.call(via_tuple(user_id), :get_warm_cache_limit)

  defp via_tuple(user_id), do: {:via, Registry, {Agents.Sessions.QueueRegistry, user_id}}

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    state = %{
      user_id: user_id,
      concurrency_limit:
        Keyword.get(opts, :concurrency_limit, SessionsConfig.default_concurrency_limit()),
      warm_cache_limit:
        Keyword.get(opts, :warm_cache_limit, SessionsConfig.default_warm_cache_limit()),
      warmup_scheduled: false,
      warming_task_ids: MapSet.new(),
      task_repo: Keyword.get(opts, :task_repo, TaskRepository),
      event_bus: Keyword.get(opts, :event_bus, Perme8.Events.EventBus),
      task_runner_starter: Keyword.get(opts, :task_runner_starter),
      container_provider: Keyword.get(opts, :container_provider, DockerAdapter),
      pubsub: Keyword.get(opts, :pubsub, SessionsConfig.pubsub())
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_snapshot, _from, state) do
    snapshot = build_current_snapshot(state)
    {:reply, snapshot, state}
  end

  @impl true
  def handle_call(:get_queue_state, _from, state) do
    snapshot = build_current_snapshot(state)
    {:reply, QueueSnapshot.to_legacy_map(snapshot), state}
  end

  @impl true
  def handle_call(:get_concurrency_limit, _from, state) do
    {:reply, state.concurrency_limit, state}
  end

  @impl true
  def handle_call(:get_warm_cache_limit, _from, state) do
    {:reply, state.warm_cache_limit, state}
  end

  @impl true
  def handle_call(:check_concurrency, _from, state) do
    snapshot = build_current_snapshot(state)
    result = if QueueSnapshot.available_slots(snapshot) > 0, do: :ok, else: :at_limit
    {:reply, result, state}
  end

  @impl true
  def handle_call({:notify_task_completed, _task_id}, _from, state) do
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_failed, task_id}, _from, state) do
    state = handle_task_failure(state, task_id)
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_cancelled, _task_id}, _from, state) do
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_question_asked, task_id}, _from, state) do
    maybe_move_to_awaiting_feedback(state, task_id)
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_feedback_provided, task_id}, _from, state) do
    maybe_requeue_after_feedback(state, task_id)
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_queued, _task_id}, _from, state) do
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_concurrency_limit, limit}, _from, state) do
    if QueuePolicy.valid_concurrency_limit?(limit) do
      state = %{state | concurrency_limit: limit}
      state = promote_and_broadcast(state)
      {:reply, :ok, state}
    else
      {:reply, {:error, :invalid_limit}, state}
    end
  end

  @impl true
  def handle_call({:set_warm_cache_limit, limit}, _from, state) do
    if QueuePolicy.valid_warm_cache_limit?(limit) do
      state = %{state | warm_cache_limit: limit}
      state = maybe_schedule_warmup(state)
      broadcast_snapshot(state)
      {:reply, :ok, state}
    else
      {:reply, {:error, :invalid_limit}, state}
    end
  end

  @impl true
  def handle_info({:retry_task, task_id}, state) do
    case state.task_repo.get_task(task_id) do
      nil ->
        {:noreply, state}

      task ->
        if task.status == "queued" and (task.retry_count || 0) > 0 do
          state = promote_and_broadcast(state)
          {:noreply, state}
        else
          {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:warm_top_queued, state) do
    _ = state.container_provider
    state = %{state | warmup_scheduled: false, warming_task_ids: MapSet.new()}
    state = promote_and_broadcast(state)
    {:noreply, state}
  end

  defp build_current_snapshot(state) do
    tasks = load_all_active_tasks(state)

    config = %{
      user_id: state.user_id,
      concurrency_limit: state.concurrency_limit,
      warm_cache_limit: state.warm_cache_limit
    }

    QueueEngine.build_snapshot(tasks, config)
  end

  # Single query for all non-terminal tasks (queued, pending, starting,
  # running, awaiting_feedback). Replaces three overlapping queries that
  # required Enum.uniq_by deduplication.
  defp load_all_active_tasks(state) do
    state.task_repo.list_non_terminal_tasks(state.user_id)
  end

  defp promote_and_broadcast(state) do
    snapshot = build_current_snapshot(state)
    promote_from_snapshot(state, snapshot)
    state = maybe_schedule_warmup(state)
    # Rebuild snapshot after promotion to capture updated task states
    post_promotion_snapshot = build_current_snapshot(state)
    broadcast_snapshot(state, post_promotion_snapshot)
    state
  end

  defp promote_from_snapshot(state, snapshot) do
    available = QueueSnapshot.available_slots(snapshot)
    promotable = QueueEngine.tasks_to_promote(snapshot, available)

    Enum.each(promotable, fn entry ->
      case state.task_repo.get_task(entry.task_id) do
        nil -> :ok
        task -> promote_single_task(state, task, entry)
      end
    end)
  end

  defp promote_single_task(state, task, entry) do
    case state.task_repo.update_task_status(task, %{
           status: "pending",
           queue_position: nil,
           queued_at: nil,
           started_at: nil,
           completed_at: nil,
           error: nil
         }) do
      {:ok, updated_task} ->
        maybe_start_runner(state, updated_task)
        emit_promotion_events(state, entry)

      {:error, reason} ->
        Logger.warning("QueueOrchestrator: failed to promote task #{task.id}: #{inspect(reason)}")
    end
  end

  defp emit_promotion_events(state, entry) do
    state.event_bus.emit(
      TaskPromoted.new(%{
        aggregate_id: entry.task_id,
        actor_id: state.user_id,
        task_id: entry.task_id,
        user_id: state.user_id
      })
    )

    state.event_bus.emit(
      TaskLaneChanged.new(%{
        aggregate_id: entry.task_id,
        actor_id: state.user_id,
        task_id: entry.task_id,
        user_id: state.user_id,
        from_lane: entry.lane,
        to_lane: :processing
      })
    )
  end

  defp handle_task_failure(state, task_id) do
    case state.task_repo.get_task(task_id) do
      nil ->
        state

      task ->
        retry_info = %{error: task.error, retry_count: task.retry_count || 0}

        if RetryPolicy.retryable?(retry_info) do
          schedule_retry(state, task)
        else
          state
        end
    end
  end

  defp schedule_retry(state, task) do
    now = DateTime.utc_now()
    new_count = (task.retry_count || 0) + 1
    delay_ms = RetryPolicy.next_retry_delay(task.retry_count || 0)
    next_retry_at = DateTime.add(now, delay_ms, :millisecond)

    case state.task_repo.update_task_status(task, %{
           status: "queued",
           retry_count: new_count,
           last_retry_at: now,
           next_retry_at: next_retry_at
         }) do
      {:ok, _updated} ->
        Process.send_after(self(), {:retry_task, task.id}, delay_ms)

        state.event_bus.emit(
          TaskRetryScheduled.new(%{
            aggregate_id: task.id,
            actor_id: state.user_id,
            task_id: task.id,
            user_id: state.user_id,
            retry_count: new_count,
            next_retry_at: next_retry_at
          })
        )

        state.event_bus.emit(
          TaskLaneChanged.new(%{
            aggregate_id: task.id,
            actor_id: state.user_id,
            task_id: task.id,
            user_id: state.user_id,
            from_lane: :processing,
            to_lane: :retry_pending
          })
        )

      {:error, reason} ->
        Logger.warning(
          "QueueOrchestrator: failed to schedule retry for #{task.id}: #{inspect(reason)}"
        )
    end

    state
  end

  defp maybe_move_to_awaiting_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil ->
        :ok

      %{status: status} = task when status in ["pending", "starting", "running"] ->
        state.task_repo.update_task_status(task, %{status: "awaiting_feedback"})

      _ ->
        :ok
    end
  end

  defp maybe_requeue_after_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil ->
        :ok

      %{status: "awaiting_feedback"} = task ->
        queue_position = (state.task_repo.get_max_queue_position(state.user_id) || 0) + 1

        state.task_repo.update_task_status(task, %{
          status: "queued",
          queue_position: queue_position,
          queued_at: DateTime.utc_now()
        })

      _ ->
        :ok
    end
  end

  defp maybe_schedule_warmup(state) do
    if state.warmup_scheduled do
      state
    else
      queued = state.task_repo.list_queued_tasks(state.user_id)

      cold_tasks =
        Enum.filter(queued, fn t ->
          is_nil(t.container_id) or String.starts_with?(t.container_id || "", "task:")
        end)

      if length(cold_tasks) > 0 and state.warm_cache_limit > 0 do
        Process.send(self(), :warm_top_queued, [])

        %{
          state
          | warmup_scheduled: true,
            warming_task_ids: MapSet.new(Enum.map(cold_tasks, & &1.id))
        }
      else
        state
      end
    end
  end

  defp maybe_start_runner(%{task_runner_starter: nil}, _task), do: :ok

  defp maybe_start_runner(state, task) do
    case state.task_runner_starter.(task.id, []) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "QueueOrchestrator: failed to start runner for #{task.id}: #{inspect(reason)}"
        )

        state.task_repo.update_task_status(task, %{
          status: "failed",
          error: "Runner failed to start: #{inspect(reason)}"
        })

        :error
    end
  end

  defp broadcast_snapshot(state, snapshot \\ nil) do
    snapshot = snapshot || build_current_snapshot(state)

    Phoenix.PubSub.broadcast(
      state.pubsub,
      "queue:user:#{state.user_id}",
      {:queue_snapshot, state.user_id, snapshot}
    )
  end
end
