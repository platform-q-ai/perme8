defmodule Agents.Sessions.Infrastructure.QueueManager do
  @moduledoc """
  Per-user queue manager for coordinating task concurrency and promotion.
  """

  use GenServer

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Events.{TaskDeprioritised, TaskPromoted}
  alias Agents.Sessions.Infrastructure.Adapters.DockerAdapter
  alias Agents.Sessions.Infrastructure.Repositories.TaskRepository

  require Logger

  @type state :: %{
          user_id: String.t(),
          concurrency_limit: integer(),
          warm_cache_limit: non_neg_integer(),
          heartbeat_interval_ms: pos_integer(),
          warmup_scheduled: boolean(),
          warming_task_ids: MapSet.t(String.t()),
          task_repo: module(),
          event_bus: module(),
          task_runner_starter: (String.t(), keyword() -> {:ok, pid()} | {:error, term()}) | nil,
          container_provider: module(),
          pubsub: module()
        }

  def start_link(opts) do
    user_id = Keyword.fetch!(opts, :user_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(user_id))
  end

  def check_concurrency(user_id) do
    GenServer.call(via_tuple(user_id), :check_concurrency)
  end

  def get_queue_state(user_id) do
    GenServer.call(via_tuple(user_id), :get_queue_state)
  end

  def get_concurrency_limit(user_id) do
    GenServer.call(via_tuple(user_id), :get_concurrency_limit)
  end

  def get_warm_cache_limit(user_id) do
    GenServer.call(via_tuple(user_id), :get_warm_cache_limit)
  end

  def set_concurrency_limit(user_id, limit) do
    GenServer.call(via_tuple(user_id), {:set_concurrency_limit, limit})
  end

  def set_warm_cache_limit(user_id, limit) do
    GenServer.call(via_tuple(user_id), {:set_warm_cache_limit, limit})
  end

  def notify_task_completed(user_id, task_id) do
    GenServer.call(via_tuple(user_id), {:notify_task_completed, task_id})
  end

  def notify_task_failed(user_id, task_id) do
    GenServer.call(via_tuple(user_id), {:notify_task_failed, task_id})
  end

  def notify_task_cancelled(user_id, task_id) do
    GenServer.call(via_tuple(user_id), {:notify_task_cancelled, task_id})
  end

  def notify_question_asked(user_id, task_id) do
    GenServer.call(via_tuple(user_id), {:notify_question_asked, task_id})
  end

  def notify_feedback_provided(user_id, task_id) do
    GenServer.call(via_tuple(user_id), {:notify_feedback_provided, task_id})
  end

  def notify_task_queued(user_id, task_id) do
    GenServer.call(via_tuple(user_id), {:notify_task_queued, task_id})
  end

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    state = %{
      user_id: user_id,
      concurrency_limit:
        Keyword.get(opts, :concurrency_limit, SessionsConfig.default_concurrency_limit()),
      warm_cache_limit: Keyword.get(opts, :warm_cache_limit, 2),
      heartbeat_interval_ms: Keyword.get(opts, :heartbeat_interval_ms, 5_000),
      warmup_scheduled: false,
      warming_task_ids: MapSet.new(),
      task_repo: Keyword.get(opts, :task_repo, TaskRepository),
      event_bus: Keyword.get(opts, :event_bus, Perme8.Events.EventBus),
      task_runner_starter: Keyword.get(opts, :task_runner_starter),
      container_provider: Keyword.get(opts, :container_provider, DockerAdapter),
      pubsub: Keyword.get(opts, :pubsub, SessionsConfig.pubsub())
    }

    schedule_heartbeat(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    state = enforce_concurrency_limit(state)
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    schedule_heartbeat(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:warm_top_queued, state) do
    warm_top_queued_tasks(state)

    state =
      state
      |> Map.put(:warmup_scheduled, false)
      |> Map.put(:warming_task_ids, MapSet.new())
      |> promote_next_task()

    broadcast_queue_updated(state)

    {:noreply, state}
  end

  @impl true
  def handle_call(:check_concurrency, _from, state) do
    running_count = safe_count_running(state)
    result = if running_count >= state.concurrency_limit, do: :at_limit, else: :ok
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_queue_state, _from, state) do
    {:reply, queue_state(state), state}
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
  def handle_call({:set_concurrency_limit, limit}, _from, state)
      when is_integer(limit) and limit >= 1 and limit <= 10 do
    state = %{state | concurrency_limit: limit}
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_concurrency_limit, _limit}, _from, state) do
    {:reply, {:error, :invalid_limit}, state}
  end

  @impl true
  def handle_call({:set_warm_cache_limit, limit}, _from, state)
      when is_integer(limit) and limit >= 0 and limit <= 5 do
    state = %{state | warm_cache_limit: limit}
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_warm_cache_limit, _limit}, _from, state) do
    {:reply, {:error, :invalid_limit}, state}
  end

  @impl true
  def handle_call({:notify_task_completed, _task_id}, _from, state) do
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_failed, _task_id}, _from, state) do
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_cancelled, _task_id}, _from, state) do
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_question_asked, task_id}, _from, state) do
    maybe_move_to_awaiting_feedback(state, task_id)
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_feedback_provided, task_id}, _from, state) do
    maybe_requeue_after_feedback(state, task_id)
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_queued, _task_id}, _from, state) do
    state = promote_next_task(state)
    state = maybe_schedule_warmup(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @deprioritisable_statuses ["pending", "starting", "running"]

  defp maybe_move_to_awaiting_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil ->
        Logger.warning("QueueManager: task #{task_id} not found for awaiting_feedback transition")

      %{status: status} = task when status in @deprioritisable_statuses ->
        case state.task_repo.update_task_status(task, %{status: "awaiting_feedback"}) do
          {:ok, _updated} ->
            emit_task_deprioritised(state, task)

          {:error, reason} ->
            Logger.warning(
              "QueueManager: failed to deprioritise task #{task_id}: #{inspect(reason)}"
            )
        end

      %{status: status} ->
        Logger.debug(
          "QueueManager: skipping deprioritise for task #{task_id} in status #{status}"
        )
    end
  end

  @requeueable_statuses ["awaiting_feedback"]

  defp maybe_requeue_after_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil ->
        Logger.warning("QueueManager: task #{task_id} not found for requeue after feedback")

      %{status: status} = task when status in @requeueable_statuses ->
        queue_position = (state.task_repo.get_max_queue_position(state.user_id) || 0) + 1

        case state.task_repo.update_task_status(task, %{
               status: "queued",
               queue_position: queue_position,
               queued_at: DateTime.utc_now()
             }) do
          {:ok, _updated} ->
            :ok

          {:error, reason} ->
            Logger.warning("QueueManager: failed to requeue task #{task_id}: #{inspect(reason)}")
        end

      %{status: status} ->
        Logger.debug("QueueManager: skipping requeue for task #{task_id} in status #{status}")
    end
  end

  defp promote_next_task(state) do
    running_count = safe_count_running(state)

    if running_count >= state.concurrency_limit do
      state
    else
      do_promote_to_capacity(state, running_count)
    end
  end

  defp do_promote_to_capacity(state, running_count) do
    if running_count >= state.concurrency_limit do
      state
    else
      do_promote_next(state, running_count)
    end
  end

  defp do_promote_next(state, running_count) do
    case state.task_repo.get_next_queued_task(state.user_id) do
      nil ->
        state

      task ->
        if warm_ready_for_promotion?(task) do
          state
          |> promote_task(task)
          |> do_promote_to_capacity(running_count + 1)
        else
          state
        end
    end
  end

  defp promote_task(state, task) do
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
        maybe_start_runner(state, updated_task, resume_prompt)
        emit_task_promoted(state, updated_task)
        state

      {:error, reason} ->
        Logger.warning("QueueManager: failed to promote task #{task.id}: #{inspect(reason)}")
        state
    end
  end

  defp emit_task_promoted(state, task) do
    state.event_bus.emit(
      TaskPromoted.new(%{
        aggregate_id: task.id,
        actor_id: state.user_id,
        task_id: task.id,
        user_id: state.user_id
      })
    )
  end

  defp emit_task_deprioritised(state, task) do
    queue_position = task.queue_position || 0

    state.event_bus.emit(
      TaskDeprioritised.new(%{
        aggregate_id: task.id,
        actor_id: state.user_id,
        task_id: task.id,
        user_id: state.user_id,
        queue_position: queue_position
      })
    )
  end

  defp maybe_start_runner(%{task_runner_starter: nil}, _task, _resume_prompt), do: :ok

  defp maybe_start_runner(state, task, resume_prompt) do
    runner_opts = runner_opts_for(task, resume_prompt)

    case state.task_runner_starter.(task.id, runner_opts) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "QueueManager: failed to start runner for promoted task #{task.id}: #{inspect(reason)}"
        )

        # Revert the task back to queued so it can be retried
        case state.task_repo.get_task(task.id) do
          nil ->
            :ok

          task ->
            state.task_repo.update_task_status(task, %{
              status: "failed",
              error: "Runner failed to start: #{inspect(reason)}"
            })
        end

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

  defp broadcast_queue_updated(state) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "queue:user:#{state.user_id}",
      {:queue_updated, state.user_id, queue_state(state)}
    )
  end

  defp queue_state(state) do
    warm_task_ids =
      state
      |> safe_list_queued()
      |> Enum.take(state.warm_cache_limit)
      |> Enum.map(& &1.id)

    %{
      running: safe_count_running(state),
      queued: safe_list_queued(state),
      awaiting_feedback: safe_list_awaiting_feedback(state),
      concurrency_limit: state.concurrency_limit,
      warm_cache_limit: state.warm_cache_limit,
      warm_task_ids: warm_task_ids,
      warming_task_ids: MapSet.to_list(state.warming_task_ids)
    }
  end

  defp safe_count_running(state) do
    state.task_repo.count_running_tasks(state.user_id)
  rescue
    e ->
      Logger.warning("QueueManager count_running failed: #{Exception.message(e)}")
      0
  end

  defp safe_list_queued(state) do
    state.task_repo.list_queued_tasks(state.user_id)
  rescue
    e ->
      Logger.warning("QueueManager list_queued failed: #{Exception.message(e)}")
      []
  end

  defp safe_list_awaiting_feedback(state) do
    state.task_repo.list_awaiting_feedback_tasks(state.user_id)
  rescue
    e ->
      Logger.warning("QueueManager list_awaiting_feedback failed: #{Exception.message(e)}")
      []
  end

  @active_statuses ["pending", "starting", "running"]

  defp enforce_concurrency_limit(state) do
    running_count = safe_count_running(state)

    if running_count <= state.concurrency_limit do
      state
    else
      excess = running_count - state.concurrency_limit

      Enum.reduce(1..excess, state, fn _, acc ->
        requeue_youngest_active_task(acc)
      end)
    end
  end

  defp requeue_youngest_active_task(state) do
    case youngest_active_task(state) do
      nil ->
        state

      task ->
        stop_runner_if_present(task.id)

        queue_position = (state.task_repo.get_max_queue_position(state.user_id) || 0) + 1

        case state.task_repo.update_task_status(task, %{
               status: "queued",
               queue_position: queue_position,
               queued_at: DateTime.utc_now()
             }) do
          {:ok, updated_task} ->
            emit_task_deprioritised(state, %{updated_task | queue_position: queue_position})
            state

          {:error, reason} ->
            Logger.warning(
              "QueueManager: failed to auto-requeue task #{task.id} while enforcing limit: #{inspect(reason)}"
            )

            state
        end
    end
  end

  defp youngest_active_task(state) do
    state.task_repo.list_tasks_for_user(state.user_id, limit: 200)
    |> Enum.filter(&(&1.status in @active_statuses))
    |> Enum.sort_by(&latest_timestamp/1, :desc)
    |> List.first()
  rescue
    e ->
      Logger.warning("QueueManager youngest_active_task failed: #{Exception.message(e)}")
      nil
  end

  defp latest_timestamp(%{inserted_at: %DateTime{} = dt}), do: DateTime.to_unix(dt, :microsecond)

  defp latest_timestamp(%{inserted_at: %NaiveDateTime{} = ndt}),
    do: NaiveDateTime.to_gregorian_seconds(ndt)

  defp latest_timestamp(_), do: 0

  defp stop_runner_if_present(task_id) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] -> GenServer.stop(pid, :normal, 5_000)
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  defp warm_top_queued_tasks(state) do
    state
    |> safe_list_queued()
    |> Enum.take(warm_target_count(state))
    |> Enum.each(&maybe_warm_task(state, &1))

    :ok
  end

  defp maybe_warm_task(state, %{container_id: nil} = task) do
    warm_task_container(state, task)
  end

  defp maybe_warm_task(state, %{container_id: container_id} = task)
       when is_binary(container_id) do
    case state.container_provider.status(container_id) do
      {:ok, :stopped} ->
        :ok

      {:ok, :running} ->
        :ok

      {:ok, :not_found} ->
        warm_task_container(state, task)

      {:error, reason} ->
        Logger.debug(
          "QueueManager: skipping warm check for task #{task.id}, status error: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp warm_task_container(state, task) do
    image = task.image || SessionsConfig.image()

    case state.container_provider.start(image, []) do
      {:ok, %{container_id: container_id}} ->
        case state.task_repo.update_task_status(task, %{
               container_id: container_id,
               container_port: nil
             }) do
          {:ok, _updated_task} ->
            :ok

          {:error, reason} ->
            Logger.debug(
              "QueueManager: failed to persist warmed container for task #{task.id}: #{inspect(reason)}"
            )
        end

        _ = state.container_provider.stop(container_id)
        :ok

      {:error, reason} ->
        Logger.debug("QueueManager: failed to warm task #{task.id}: #{inspect(reason)}")
        :ok
    end
  end

  defp schedule_heartbeat(state) do
    Process.send_after(self(), :heartbeat, state.heartbeat_interval_ms)
  end

  defp maybe_schedule_warmup(%{warmup_scheduled: true} = state), do: state

  defp maybe_schedule_warmup(state) do
    warming_task_ids =
      state
      |> safe_list_queued()
      |> Enum.take(warm_target_count(state))
      |> Enum.filter(&needs_warm?/1)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    if MapSet.size(warming_task_ids) == 0 do
      state
    else
      Process.send(self(), :warm_top_queued, [])
      %{state | warmup_scheduled: true, warming_task_ids: warming_task_ids}
    end
  end

  defp needs_warm?(%{container_id: nil}), do: true

  defp needs_warm?(%{container_id: container_id}) when is_binary(container_id) do
    String.starts_with?(container_id, "task:")
  end

  defp needs_warm?(_), do: false

  defp warm_ready_for_promotion?(%{container_id: container_id}) when is_binary(container_id) do
    not String.starts_with?(container_id, "task:")
  end

  defp warm_ready_for_promotion?(_), do: false

  defp warm_target_count(state) do
    available_slots = max(state.concurrency_limit - safe_count_running(state), 0)
    max(state.warm_cache_limit, available_slots)
  end

  defp via_tuple(user_id) do
    {:via, Registry, {Agents.Sessions.QueueRegistry, user_id}}
  end
end
