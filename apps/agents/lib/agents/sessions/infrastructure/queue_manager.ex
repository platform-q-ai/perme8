defmodule Agents.Sessions.Infrastructure.QueueManager do
  @moduledoc """
  Per-user queue manager for coordinating task concurrency and promotion.
  """

  use GenServer

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Events.TaskPromoted
  alias Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @type state :: %{
          user_id: String.t(),
          concurrency_limit: integer(),
          task_repo: module(),
          event_bus: module(),
          task_runner_starter: (String.t(), keyword() -> {:ok, pid()} | {:error, term()}) | nil,
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

  def set_concurrency_limit(user_id, limit) do
    GenServer.call(via_tuple(user_id), {:set_concurrency_limit, limit})
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

  @impl true
  def init(opts) do
    user_id = Keyword.fetch!(opts, :user_id)

    {:ok,
     %{
       user_id: user_id,
       concurrency_limit:
         Keyword.get(opts, :concurrency_limit, SessionsConfig.default_concurrency_limit()),
       task_repo: Keyword.get(opts, :task_repo, TaskRepository),
       event_bus: Keyword.get(opts, :event_bus, Perme8.Events.EventBus),
       task_runner_starter: Keyword.get(opts, :task_runner_starter),
       pubsub: Keyword.get(opts, :pubsub, SessionsConfig.pubsub())
     }}
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
  def handle_call({:set_concurrency_limit, limit}, _from, state) do
    state = %{state | concurrency_limit: limit}
    state = promote_next_task(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_completed, _task_id}, _from, state) do
    state = promote_next_task(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_failed, _task_id}, _from, state) do
    state = promote_next_task(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_task_cancelled, _task_id}, _from, state) do
    state = promote_next_task(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_question_asked, task_id}, _from, state) do
    maybe_move_to_awaiting_feedback(state, task_id)
    state = promote_next_task(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:notify_feedback_provided, task_id}, _from, state) do
    maybe_requeue_after_feedback(state, task_id)
    state = promote_next_task(state)
    broadcast_queue_updated(state)
    {:reply, :ok, state}
  end

  defp maybe_move_to_awaiting_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil -> :ok
      task -> state.task_repo.update_task_status(task, %{status: "awaiting_feedback"})
    end
  end

  defp maybe_requeue_after_feedback(state, task_id) do
    case state.task_repo.get_task_for_user(task_id, state.user_id) do
      nil ->
        :ok

      task ->
        queue_position = (state.task_repo.get_max_queue_position(state.user_id) || 0) + 1

        state.task_repo.update_task_status(task, %{
          status: "queued",
          queue_position: queue_position,
          queued_at: DateTime.utc_now()
        })
    end
  end

  defp promote_next_task(state) do
    running_count = safe_count_running(state)

    if running_count >= state.concurrency_limit do
      state
    else
      case state.task_repo.get_next_queued_task(state.user_id) do
        nil ->
          state

        task ->
          with {:ok, updated_task} <-
                 state.task_repo.update_task_status(task, %{
                   status: "pending",
                   queue_position: nil,
                   queued_at: nil
                 }) do
            maybe_start_runner(state, updated_task.id)

            state.event_bus.emit(
              TaskPromoted.new(%{
                aggregate_id: updated_task.id,
                actor_id: state.user_id,
                task_id: updated_task.id,
                user_id: state.user_id
              })
            )

            state
          else
            _ -> state
          end
      end
    end
  end

  defp maybe_start_runner(%{task_runner_starter: nil}, _task_id), do: :ok

  defp maybe_start_runner(state, task_id) do
    _ = state.task_runner_starter.(task_id, [])
    :ok
  end

  defp broadcast_queue_updated(state) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "queue:user:#{state.user_id}",
      {:queue_updated, state.user_id, queue_state(state)}
    )
  end

  defp queue_state(state) do
    %{
      running: safe_count_running(state),
      queued: safe_list_queued(state),
      awaiting_feedback: safe_list_awaiting_feedback(state),
      concurrency_limit: state.concurrency_limit
    }
  end

  defp safe_count_running(state) do
    state.task_repo.count_running_tasks(state.user_id)
  rescue
    _ -> 0
  end

  defp safe_list_queued(state) do
    state.task_repo.list_queued_tasks(state.user_id)
  rescue
    _ -> []
  end

  defp safe_list_awaiting_feedback(state) do
    state.task_repo.list_awaiting_feedback_tasks(state.user_id)
  rescue
    _ -> []
  end

  defp via_tuple(user_id) do
    {:via, Registry, {Agents.Sessions.QueueRegistry, user_id}}
  end
end
