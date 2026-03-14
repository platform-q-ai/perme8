defmodule Agents.Sessions.Infrastructure.QueueOrchestrator do
  @moduledoc """
  Per-user queue orchestrator. Single source of truth for queue state,
  delegating policy decisions to QueueEngine and RetryPolicy.
  """

  use GenServer

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Events.{TaskLaneChanged, TaskPromoted, TaskRetryScheduled}

  alias Agents.Sessions.Domain.Policies.{
    QueueEngine,
    QueuePolicy,
    RetryPolicy,
    SessionLifecyclePolicy
  }

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

  # After schedule_retry moves the task to "queued" with retry_count > 0,
  # promote_and_broadcast is safe: QueueEngine.promotable_tasks/1 only returns
  # :warm and :cold entries, never :retry_pending. Retry-pending tasks wait
  # for their scheduled {:retry_task, id} timer before becoming promotable.
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

  # Container pre-warming: starts containers for cold queued tasks up to
  # warm_cache_limit. Containers stay running so promotion can skip the
  # full cold-start health check cycle. Wrapped in try/rescue for
  # resilience when DB connections are unavailable (e.g., in test sandbox).
  @impl true
  def handle_info(:warm_top_queued, state) do
    state = %{state | warmup_scheduled: false}

    try do
      warm_top_queued_tasks(state)
    rescue
      e ->
        Logger.warning("QueueOrchestrator: warming failed: #{Exception.message(e)}")
    end

    state = %{state | warming_task_ids: MapSet.new()}

    try do
      broadcast_snapshot(state)
    rescue
      _ -> :ok
    end

    {:noreply, state}
  end

  # Handles the result of an async container warming task. Updates the
  # task in the DB with the new container_id and container_port.
  # Wrapped in try/rescue for resilience in test environments.
  @impl true
  def handle_info({:warm_result, task_id, result}, state) do
    try do
      case result do
        {:ok, container_id, port} ->
          case state.task_repo.get_task(task_id) do
            nil ->
              :ok

            task ->
              state.task_repo.update_task_status(task, %{
                container_id: container_id,
                container_port: port
              })
          end

        {:error, reason} ->
          Logger.warning(
            "QueueOrchestrator: warming failed for task #{task_id}: #{inspect(reason)}"
          )
      end

      broadcast_snapshot(state)
    rescue
      e ->
        Logger.warning(
          "QueueOrchestrator: warm_result handling failed for task #{task_id}: #{Exception.message(e)}"
        )
    end

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
  # required Enum.uniq_by deduplication. Returns empty list on DB errors
  # to prevent GenServer crashes in environments without DB access.
  defp load_all_active_tasks(state) do
    state.task_repo.list_non_terminal_tasks(state.user_id)
  rescue
    _ -> []
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
    # Pass 1: promote all queued light image tasks (bypass concurrency limit)
    light_entries = QueueEngine.light_image_tasks_to_promote(snapshot)

    Enum.each(light_entries, fn entry ->
      case state.task_repo.get_task(entry.task_id) do
        nil -> :ok
        task -> promote_single_task(state, task, entry)
      end
    end)

    # Pass 2: promote heavyweight tasks up to available concurrency slots
    available = QueueSnapshot.available_slots(snapshot)
    heavyweight_entries = QueueEngine.heavyweight_tasks_to_promote(snapshot, available)

    Enum.each(heavyweight_entries, fn entry ->
      case state.task_repo.get_task(entry.task_id) do
        nil -> :ok
        task -> promote_single_task(state, task, entry)
      end
    end)
  end

  defp promote_single_task(state, task, entry) do
    resume_prompt = queued_resume_prompt(task.pending_question)

    case state.task_repo.update_task_status(task, %{
           status: "pending",
           queue_position: nil,
           queued_at: nil,
           started_at: nil,
           completed_at: nil,
           error: nil,
           pending_question: clear_resume_prompt(task.pending_question)
         }) do
      {:ok, updated_task} ->
        broadcast_task_status_and_lifecycle(state, task, updated_task, "pending")
        maybe_start_runner(state, updated_task, resume_prompt)
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
        updated_task = %{
          task
          | status: "queued",
            retry_count: new_count,
            next_retry_at: next_retry_at
        }

        broadcast_task_status_and_lifecycle(state, task, updated_task, "queued")

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
        case state.task_repo.update_task_status(task, %{status: "awaiting_feedback"}) do
          {:ok, updated_task} ->
            broadcast_task_status_and_lifecycle(state, task, updated_task, "awaiting_feedback")

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp maybe_requeue_after_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil ->
        :ok

      %{status: "awaiting_feedback"} = task ->
        # Stop the container before re-queuing — warming will restart it
        maybe_stop_container_for_requeue(state, task)

        queue_position = (state.task_repo.get_max_queue_position(state.user_id) || 0) + 1

        case state.task_repo.update_task_status(task, %{
               status: "queued",
               queue_position: queue_position,
               queued_at: DateTime.utc_now(),
               container_port: nil
             }) do
          {:ok, updated_task} ->
            broadcast_task_status_and_lifecycle(state, task, updated_task, "queued")

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp maybe_stop_container_for_requeue(state, %{container_id: cid})
       when is_binary(cid) and cid != "" do
    state.container_provider.stop(cid)
  end

  defp maybe_stop_container_for_requeue(_state, _task), do: :ok

  # Schedules a deferred warmup if there are queued tasks (cold or warm
  # with stale containers) and the warm_cache_limit allows it. Uses
  # send_after to avoid triggering warming synchronously during promotion.
  @warmup_delay_ms 1_000
  defp maybe_schedule_warmup(state) do
    if state.warmup_scheduled do
      state
    else
      snapshot = build_current_snapshot(state)
      warmable_tasks = snapshot.lanes.cold ++ snapshot.lanes.warm

      if warmable_tasks != [] and state.warm_cache_limit > 0 do
        Process.send_after(self(), :warm_top_queued, @warmup_delay_ms)

        %{
          state
          | warmup_scheduled: true,
            warming_task_ids: MapSet.new(Enum.map(warmable_tasks, & &1.task_id))
        }
      else
        state
      end
    end
  end

  # Warms the top N queued tasks (N = warm_cache_limit) by starting
  # containers for cold tasks and checking status for tasks with
  # existing containers. Considers both cold-lane and warm-lane tasks
  # since warm-lane tasks may have stale/missing containers.
  defp warm_top_queued_tasks(state) do
    tasks =
      state.task_repo.list_non_terminal_tasks(state.user_id)
      |> Enum.filter(&(&1.status == "queued"))
      |> Enum.sort_by(& &1.queue_position)
      |> Enum.take(state.warm_cache_limit)

    Enum.each(tasks, &maybe_warm_task(state, &1))
  end

  defp maybe_warm_task(state, %{container_id: nil} = task) do
    warm_task_container(state, task)
  end

  defp maybe_warm_task(state, %{container_id: container_id} = task)
       when is_binary(container_id) do
    case state.container_provider.status(container_id) do
      {:ok, :running} ->
        # Already warm and running — nothing to do
        :ok

      {:ok, :stopped} ->
        # Restart the stopped container
        restart_warm_container(state, task, container_id)

      {:ok, :not_found} ->
        # Container gone — start a fresh one
        warm_task_container(state, task)

      {:error, _reason} ->
        :ok
    end
  end

  defp maybe_warm_task(_state, _task), do: :ok

  # Starts a new container asynchronously and sends the result back
  # to the orchestrator GenServer. Uses Task.start (unlinked) so a
  # container start failure doesn't crash the GenServer.
  defp warm_task_container(state, task) do
    image = Map.get(task, :image) || SessionsConfig.image()
    container_provider = state.container_provider
    task_id = task.id
    orchestrator = self()

    Task.start(fn ->
      result =
        try do
          case container_provider.start(image, []) do
            {:ok, %{container_id: container_id, port: port}} ->
              {:ok, container_id, port}

            {:error, reason} ->
              {:error, reason}
          end
        rescue
          e -> {:error, Exception.message(e)}
        end

      send(orchestrator, {:warm_result, task_id, result})
    end)
  end

  # Restarts an existing stopped container asynchronously.
  defp restart_warm_container(state, task, container_id) do
    container_provider = state.container_provider
    task_id = task.id
    orchestrator = self()

    Task.start(fn ->
      result =
        try do
          case container_provider.restart(container_id) do
            {:ok, %{port: port}} ->
              {:ok, container_id, port}

            {:error, reason} ->
              {:error, reason}
          end
        rescue
          e -> {:error, Exception.message(e)}
        end

      send(orchestrator, {:warm_result, task_id, result})
    end)
  end

  defp maybe_start_runner(%{task_runner_starter: nil}, _task, _resume_prompt), do: :ok

  defp maybe_start_runner(state, task, resume_prompt) do
    runner_opts = runner_opts_for(task, resume_prompt)

    case state.task_runner_starter.(task.id, runner_opts) do
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

  defp runner_opts_for(
         %{container_id: cid, session_id: sid, instruction: instruction},
         prompt_instruction
       )
       when is_binary(prompt_instruction) and prompt_instruction != "" and is_binary(cid) and
              cid != "" and
              is_binary(sid) and sid != "" do
    [
      resume: true,
      instruction: instruction,
      prompt_instruction: prompt_instruction,
      container_id: cid,
      session_id: sid
    ]
  end

  # Note: `already_healthy: true` reflects container health at warming time.
  # There is a TOCTOU gap — by promotion time the container could have crashed.
  # This is an accepted tradeoff: if TaskRunner's `prepare_fresh_start` fails,
  # the task is marked failed and will be retried via RetryPolicy. A pre-promotion
  # health check would add latency to every promotion without meaningfully
  # narrowing the race window.
  defp runner_opts_for(
         %{container_id: cid, session_id: nil, container_port: port},
         _resume_prompt
       )
       when is_binary(cid) and cid != "" and is_integer(port) do
    [
      prewarmed_container_id: cid,
      container_port: port,
      already_healthy: true,
      fresh_warm_container: true
    ]
  end

  defp runner_opts_for(%{container_id: cid, session_id: nil}, _resume_prompt)
       when is_binary(cid) and cid != "" do
    [
      prewarmed_container_id: cid,
      fresh_warm_container: true
    ]
  end

  defp runner_opts_for(_task, _resume_prompt), do: []

  defp queued_resume_prompt(%{"resume_prompt" => prompt}) when is_binary(prompt), do: prompt
  defp queued_resume_prompt(_), do: nil

  defp clear_resume_prompt(%{"resume_prompt" => _} = pending_question) do
    case Map.delete(pending_question, "resume_prompt") do
      map when map_size(map) == 0 -> nil
      map -> map
    end
  end

  defp clear_resume_prompt(other), do: other

  defp broadcast_snapshot(state, snapshot \\ nil) do
    snapshot = snapshot || build_current_snapshot(state)

    Phoenix.PubSub.broadcast(
      state.pubsub,
      "queue:user:#{state.user_id}",
      {:queue_snapshot, state.user_id, snapshot}
    )
  end

  defp broadcast_task_status_and_lifecycle(state, from_task, to_task, status) do
    from_state = lifecycle_state(from_task)
    to_state = lifecycle_state(to_task)
    container_id = Map.get(to_task, :container_id)

    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{to_task.id}",
      {:task_status_changed, to_task.id, status}
    )

    Logger.debug(
      "Session lifecycle transition: #{from_state} -> #{to_state} [task=#{to_task.id}, container=#{container_id}]"
    )

    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{to_task.id}",
      {:lifecycle_state_changed, to_task.id, from_state, to_state}
    )
  end

  defp lifecycle_state(nil), do: :idle

  defp lifecycle_state(task) do
    SessionLifecyclePolicy.derive(%{
      status: Map.get(task, :status),
      container_id: Map.get(task, :container_id),
      container_port: Map.get(task, :container_port)
    })
  end
end
