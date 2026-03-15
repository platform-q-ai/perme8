defmodule Agents.Sessions.Infrastructure.TaskRunner.TaskBroadcaster do
  @moduledoc """
  PubSub broadcast functions extracted from TaskRunner.

  All functions are stateless — they take explicit parameters (task_id, pubsub, etc.)
  and broadcast messages to the `"task:\#{task_id}"` topic. No GenServer state is
  accessed directly; the calling GenServer passes in the values it needs broadcast.
  """

  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy

  require Logger

  @doc """
  Broadcasts a raw SSE event to subscribers.

  Message: `{:task_event, task_id, event}`
  """
  def broadcast_event(event, task_id, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_event, task_id, event}
    )
  end

  @doc """
  Broadcasts a status change.

  Message: `{:task_status_changed, task_id, status}`
  """
  def broadcast_status(task_id, status, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_status_changed, task_id, status}
    )
  end

  @doc """
  Broadcasts both a status change and a lifecycle state transition.

  Computes the lifecycle state transition by comparing the current task
  (before update) with the target task (after applying attrs and status).
  """
  def broadcast_status_with_lifecycle(task_id, pubsub, status, attrs, current_task) do
    to_task = lifecycle_target_task(current_task, attrs, status)

    from_state = lifecycle_state_from_task(current_task)
    to_state = lifecycle_state_from_task(to_task)
    container_id = Map.get(to_task, :container_id)

    broadcast_status(task_id, status, pubsub)

    broadcast_lifecycle_transition(
      task_id,
      from_state,
      to_state,
      container_id,
      pubsub
    )
  end

  @doc """
  Broadcasts a lifecycle state transition.

  Message: `{:lifecycle_state_changed, task_id, from_state, to_state}`
  """
  def broadcast_lifecycle_transition(task_id, from_state, to_state, container_id, pubsub) do
    Logger.debug(
      "Session lifecycle transition: #{from_state} -> #{to_state} [task=#{task_id}, container=#{container_id}]"
    )

    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:lifecycle_state_changed, task_id, from_state, to_state}
    )
  end

  @doc """
  Broadcasts that a session ID has been set for a task.

  Message: `{:task_session_id_set, task_id, session_id}`
  """
  def broadcast_session_id_set(task_id, session_id, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_session_id_set, task_id, session_id}
    )
  end

  @doc """
  Broadcasts that a question has been replied to.

  Message: `{:task_event, task_id, %{"type" => "question.replied"}}`
  """
  def broadcast_question_replied(task_id, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_event, task_id, %{"type" => "question.replied"}}
    )
  end

  @doc """
  Broadcasts that a question has been rejected.

  Message: `{:task_event, task_id, %{"type" => "question.rejected"}}`
  """
  def broadcast_question_rejected(task_id, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_event, task_id, %{"type" => "question.rejected"}}
    )
  end

  @doc """
  Broadcasts container resource stats (CPU, memory).

  Fetches stats from the container provider and broadcasts them.
  Silently handles errors — stats are best-effort telemetry.

  Message: `{:container_stats_updated, task_id, container_id, payload}`
  """
  def broadcast_container_stats(container_id, container_provider, task_id, pubsub)
      when is_binary(container_id) do
    case container_provider.stats(container_id) do
      {:ok, stats} ->
        mem_percent =
          if stats.memory_limit > 0,
            do: Float.round(stats.memory_usage / stats.memory_limit * 100, 1),
            else: 0.0

        payload = %{
          cpu_percent: stats.cpu_percent,
          memory_percent: mem_percent,
          memory_usage: stats.memory_usage,
          memory_limit: stats.memory_limit
        }

        Phoenix.PubSub.broadcast(
          pubsub,
          "task:#{task_id}",
          {:container_stats_updated, task_id, container_id, payload}
        )

      {:error, _} ->
        :ok
    end
  rescue
    _ -> :ok
  end

  def broadcast_container_stats(_container_id, _container_provider, _task_id, _pubsub), do: :ok

  @doc """
  Broadcasts a todo list update.

  Message: `{:todo_updated, task_id, todo_items}`
  """
  def broadcast_todo_update(task_id, todo_items, pubsub) do
    Phoenix.PubSub.broadcast(pubsub, "task:#{task_id}", {:todo_updated, task_id, todo_items})
  end

  @doc """
  Builds a target task map by merging attrs into the current task and setting the status.
  Used for computing lifecycle state transitions.
  """
  def lifecycle_target_task(nil, attrs, status) do
    attrs
    |> Map.new()
    |> Map.put_new(:status, status)
  end

  def lifecycle_target_task(%_{} = task, attrs, status) do
    task
    |> Map.from_struct()
    |> Map.merge(Map.new(attrs))
    |> Map.put(:status, status)
  end

  def lifecycle_target_task(task, attrs, status) when is_map(task) do
    task
    |> Map.merge(Map.new(attrs))
    |> Map.put(:status, status)
  end

  @doc """
  Derives the lifecycle state from a task map.
  Delegates to `SessionLifecyclePolicy.derive/1`.
  """
  def lifecycle_state_from_task(nil), do: :idle

  def lifecycle_state_from_task(task) do
    SessionLifecyclePolicy.derive(%{
      status: Map.get(task, :status),
      container_id: Map.get(task, :container_id),
      container_port: Map.get(task, :container_port)
    })
  end
end
