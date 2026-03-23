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

  alias Agents.Sessions.Infrastructure.Repositories.{SessionRepository, TaskRepository}

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

  def notify_session_activity(user_id, session_id),
    do: GenServer.call(via_tuple(user_id), {:notify_session_activity, session_id})

  def set_concurrency_limit(user_id, limit),
    do: GenServer.call(via_tuple(user_id), {:set_concurrency_limit, limit})

  def get_queue_state(user_id), do: GenServer.call(via_tuple(user_id), :get_queue_state)

  def get_concurrency_limit(user_id),
    do: GenServer.call(via_tuple(user_id), :get_concurrency_limit)

  defp via_tuple(user_id), do: {:via, Registry, {Agents.Sessions.QueueRegistry, user_id}}

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    state = %{
      user_id: user_id,
      concurrency_limit:
        Keyword.get(opts, :concurrency_limit, SessionsConfig.default_concurrency_limit()),
      task_repo: Keyword.get(opts, :task_repo, TaskRepository),
      session_repo: Keyword.get(opts, :session_repo, SessionRepository),
      container_provider:
        Keyword.get(
          opts,
          :container_provider,
          Application.get_env(
            :agents,
            :container_provider,
            Agents.Sessions.Infrastructure.Adapters.DockerAdapter
          )
        ),
      idle_timeout_ms:
        Keyword.get(opts, :idle_timeout_ms, SessionsConfig.idle_suspend_timeout_ms()),
      idle_timers: %{},
      event_bus: Keyword.get(opts, :event_bus, Perme8.Events.EventBus),
      task_runner_starter: Keyword.get(opts, :task_runner_starter),
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
  def handle_call(:check_concurrency, _from, state) do
    snapshot = build_current_snapshot(state)
    result = if QueueSnapshot.available_slots(snapshot) > 0, do: :ok, else: :at_limit
    {:reply, result, state}
  end

  @impl true
  def handle_call({:notify_task_completed, task_id}, _from, state) do
    state = schedule_idle_suspend_for_task(state, task_id)
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
  def handle_call({:notify_task_queued, task_id}, _from, state) do
    state = cancel_idle_suspend_for_task(state, task_id)
    state = promote_and_broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_session_activity, session_id}, _from, state) do
    state = cancel_idle_suspend_for_session(state, session_id)
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
  def handle_info({:retry_task, task_id}, state) do
    case safe_get_task(state, task_id) do
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
  def handle_info({:suspend_idle_session, session_id}, state) do
    state = maybe_suspend_idle_session(state, session_id)
    {:noreply, %{state | idle_timers: Map.delete(state.idle_timers, session_id)}}
  end

  defp build_current_snapshot(state) do
    tasks = load_all_active_tasks(state)

    config = %{
      user_id: state.user_id,
      concurrency_limit: state.concurrency_limit
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
    # Rebuild snapshot after promotion to capture updated task states
    post_promotion_snapshot = build_current_snapshot(state)
    broadcast_snapshot(state, post_promotion_snapshot)
    state
  end

  defp promote_from_snapshot(state, snapshot) do
    available = QueueSnapshot.available_slots(snapshot)

    snapshot
    |> QueueEngine.promotable_tasks()
    |> Enum.take(available)
    |> Enum.each(fn entry ->
      case safe_get_task(state, entry.task_id) do
        nil -> :ok
        task -> promote_single_task(state, task, entry)
      end
    end)
  end

  defp promote_single_task(state, task, entry) do
    resume_prompt = queued_resume_prompt(task.pending_question)

    case safe_update_task_status(state, task, %{
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
    case safe_get_task(state, task_id) do
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

    case safe_update_task_status(state, task, %{
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
    case safe_get_task_for_user(state, task_id) do
      nil ->
        :ok

      %{status: status} = task when status in ["pending", "starting", "running"] ->
        case safe_update_task_status(state, task, %{status: "awaiting_feedback"}) do
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
    case safe_get_task_for_user(state, task_id) do
      nil ->
        :ok

      %{status: "awaiting_feedback"} = task ->
        queue_position = (safe_get_max_queue_position(state) || 0) + 1

        case safe_update_task_status(state, task, %{
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

        _ =
          safe_update_task_status(state, task, %{
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

  defp safe_get_task(state, task_id) do
    state.task_repo.get_task(task_id)
  rescue
    error ->
      Logger.warning("QueueOrchestrator: failed to load task #{task_id}: #{inspect(error)}")
      nil
  end

  defp safe_get_task_for_user(state, task_id) do
    state.task_repo.get_task_for_user(task_id, state.user_id)
  rescue
    error ->
      Logger.warning(
        "QueueOrchestrator: failed to load task #{task_id} for user #{state.user_id}: #{inspect(error)}"
      )

      nil
  end

  defp safe_get_max_queue_position(state) do
    state.task_repo.get_max_queue_position(state.user_id)
  rescue
    error ->
      Logger.warning(
        "QueueOrchestrator: failed to load max queue position for user #{state.user_id}: #{inspect(error)}"
      )

      nil
  end

  defp safe_update_task_status(state, task, attrs) do
    state.task_repo.update_task_status(task, attrs)
  rescue
    error ->
      Logger.warning("QueueOrchestrator: failed to update task #{task.id}: #{inspect(error)}")
      {:error, error}
  end

  defp schedule_idle_suspend_for_task(state, task_id) do
    with %{session_ref_id: session_id, status: status}
         when is_binary(session_id) <- safe_get_task(state, task_id),
         :idle <- SessionLifecyclePolicy.derive_ticket_session_state(status) do
      timer_ref =
        Process.send_after(self(), {:suspend_idle_session, session_id}, state.idle_timeout_ms)

      maybe_cancel_timer(Map.get(state.idle_timers, session_id))
      %{state | idle_timers: Map.put(state.idle_timers, session_id, timer_ref)}
    else
      _ -> state
    end
  end

  defp cancel_idle_suspend_for_task(state, task_id) do
    case safe_get_task(state, task_id) do
      %{session_ref_id: session_id} when is_binary(session_id) ->
        cancel_idle_suspend_for_session(state, session_id)

      _ ->
        state
    end
  end

  defp cancel_idle_suspend_for_session(state, session_id) when is_binary(session_id) do
    maybe_cancel_timer(Map.get(state.idle_timers, session_id))
    touch_session_activity(state, session_id)
    %{state | idle_timers: Map.delete(state.idle_timers, session_id)}
  end

  defp cancel_idle_suspend_for_session(state, _session_id), do: state

  defp maybe_suspend_idle_session(state, session_id) do
    case state.session_repo.get_session_for_user(session_id, state.user_id) do
      %{status: "active"} = session ->
        if no_active_tasks_for_session?(state, session_id) do
          _ = maybe_stop_session_container(state.container_provider, session.container_id)

          _ =
            state.session_repo.update_session(session, %{
              status: "paused",
              container_status: "stopped",
              paused_at: DateTime.utc_now(),
              last_activity_at: DateTime.utc_now(),
              container_port: nil
            })

          state
        else
          state
        end

      _ ->
        state
    end
  end

  defp no_active_tasks_for_session?(state, session_id) do
    state
    |> load_all_active_tasks()
    |> Enum.any?(fn task -> Map.get(task, :session_ref_id) == session_id end)
    |> Kernel.not()
  end

  defp maybe_stop_session_container(_container_provider, nil), do: :ok

  defp maybe_stop_session_container(container_provider, container_id) do
    container_provider.stop(container_id)
  rescue
    _ -> :ok
  end

  defp maybe_cancel_timer(nil), do: :ok
  defp maybe_cancel_timer(timer_ref), do: Process.cancel_timer(timer_ref)

  defp touch_session_activity(state, session_id) do
    case state.session_repo.get_session_for_user(session_id, state.user_id) do
      %{status: status} = session when status in ["active", "paused"] ->
        _ = state.session_repo.update_session(session, %{last_activity_at: DateTime.utc_now()})
        :ok

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end

  defp broadcast_snapshot(state, snapshot) do
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
