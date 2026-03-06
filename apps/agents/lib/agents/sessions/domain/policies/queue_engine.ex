defmodule Agents.Sessions.Domain.Policies.QueueEngine do
  @moduledoc """
  Pure queue orchestration policy for lane assignment and promotion rules.
  """

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}

  @type lane :: :processing | :warm | :cold | :awaiting_feedback | :retry_pending | :terminal

  @valid_transitions MapSet.new([
                       {"queued", "pending"},
                       {"pending", "starting"},
                       {"starting", "running"},
                       {"running", "completed"},
                       {"running", "failed"},
                       {"running", "cancelled"},
                       {"queued", "cancelled"},
                       {"awaiting_feedback", "queued"},
                       {"pending", "cancelled"},
                       {"starting", "cancelled"},
                       {"running", "awaiting_feedback"}
                     ])

  @doc """
  Assigns a queue lane for a task-like map.
  """
  @spec assign_lane(map()) :: lane()
  def assign_lane(task) when is_map(task) do
    case value(task, :status) do
      status when status in ["pending", "starting", "running"] -> :processing
      "awaiting_feedback" -> :awaiting_feedback
      "queued" -> assign_queued_lane(task)
      _terminal -> :terminal
    end
  end

  defp assign_queued_lane(task) do
    retry_count = value(task, :retry_count) || 0

    cond do
      retry_count > 0 -> :retry_pending
      real_container?(value(task, :container_id)) -> :warm
      true -> :cold
    end
  end

  @doc """
  Classifies the warm state from container metadata.
  """
  @spec classify_warm_state(map()) :: LaneEntry.warm_state()
  def classify_warm_state(task) when is_map(task) do
    container_id = value(task, :container_id)
    port = value(task, :container_port) || value(task, :port)

    cond do
      not real_container?(container_id) -> :cold
      is_nil(port) -> :warming
      value(task, :status) == "running" -> :hot
      true -> :warm
    end
  end

  @doc """
  Builds a queue snapshot from tasks and runtime config.
  """
  @spec build_snapshot([map()], map()) :: QueueSnapshot.t()
  def build_snapshot(tasks, config) when is_list(tasks) and is_map(config) do
    lane_entries =
      tasks
      |> Enum.reject(&(assign_lane(&1) == :terminal))
      |> Enum.map(&to_lane_entry/1)

    lanes = %{
      processing: lane_entries |> filter_lane(:processing) |> sort_processing(),
      warm: lane_entries |> filter_lane(:warm) |> sort_by_queue_position(),
      cold: lane_entries |> filter_lane(:cold) |> sort_by_queue_position(),
      awaiting_feedback: lane_entries |> filter_lane(:awaiting_feedback),
      retry_pending: lane_entries |> filter_lane(:retry_pending) |> sort_by_queue_position()
    }

    running_count =
      lanes.processing
      |> Enum.reject(&LaneEntry.light_image?/1)
      |> length()

    concurrency_limit = config[:concurrency_limit] || 2
    warm_cache_limit = config[:warm_cache_limit] || 2

    QueueSnapshot.new(%{
      user_id: config[:user_id],
      lanes: lanes,
      metadata: %{
        concurrency_limit: concurrency_limit,
        warm_cache_limit: warm_cache_limit,
        running_count: running_count,
        available_slots: concurrency_limit - running_count,
        total_queued: length(lanes.warm) + length(lanes.cold) + length(lanes.retry_pending)
      }
    })
  end

  @doc """
  Returns true when a task can transition between statuses.
  """
  @spec can_transition?(String.t(), String.t()) :: boolean()
  def can_transition?(from_status, to_status) do
    MapSet.member?(@valid_transitions, {from_status, to_status})
  end

  @doc """
  Returns warm + cold tasks sorted by promotion priority.
  """
  @spec promotable_tasks(QueueSnapshot.t()) :: [LaneEntry.t()]
  def promotable_tasks(%QueueSnapshot{} = snapshot) do
    warm = sort_by_queue_position(snapshot.lanes.warm)
    cold = sort_by_queue_position(snapshot.lanes.cold)
    warm ++ cold
  end

  @doc """
  Returns up to N tasks to promote.
  """
  @spec tasks_to_promote(QueueSnapshot.t(), integer()) :: [LaneEntry.t()]
  def tasks_to_promote(%QueueSnapshot{} = _snapshot, available_slots) when available_slots <= 0,
    do: []

  def tasks_to_promote(%QueueSnapshot{} = snapshot, available_slots) do
    snapshot
    |> promotable_tasks()
    |> Enum.take(available_slots)
  end

  @doc """
  Returns all queued light image tasks that should be promoted regardless of
  available concurrency slots. Light image tasks bypass the concurrency limit.
  """
  @spec light_image_tasks_to_promote(QueueSnapshot.t()) :: [LaneEntry.t()]
  def light_image_tasks_to_promote(%QueueSnapshot{} = snapshot) do
    snapshot
    |> promotable_tasks()
    |> Enum.filter(&LaneEntry.light_image?/1)
  end

  @doc """
  Returns up to N heavyweight (non-light-image) tasks to promote.
  Used for the concurrency-limited promotion pass.
  """
  @spec heavyweight_tasks_to_promote(QueueSnapshot.t(), integer()) :: [LaneEntry.t()]
  def heavyweight_tasks_to_promote(%QueueSnapshot{} = _snapshot, available_slots)
      when available_slots <= 0,
      do: []

  def heavyweight_tasks_to_promote(%QueueSnapshot{} = snapshot, available_slots) do
    snapshot
    |> promotable_tasks()
    |> Enum.reject(&LaneEntry.light_image?/1)
    |> Enum.take(available_slots)
  end

  defp to_lane_entry(task) do
    LaneEntry.new(%{
      task_id: value(task, :id) || value(task, :task_id),
      instruction: value(task, :instruction),
      status: value(task, :status),
      lane: assign_lane(task),
      container_id: value(task, :container_id),
      warm_state: classify_warm_state(task),
      queue_position: value(task, :queue_position),
      retry_count: value(task, :retry_count) || 0,
      error: value(task, :error),
      queued_at: value(task, :queued_at),
      started_at: value(task, :started_at),
      image: value(task, :image)
    })
  end

  defp filter_lane(entries, lane), do: Enum.filter(entries, &(&1.lane == lane))

  defp sort_processing(entries) do
    Enum.sort_by(entries, fn entry ->
      case entry.started_at do
        nil -> {1, nil}
        started_at -> {0, started_at}
      end
    end)
  end

  defp sort_by_queue_position(entries) do
    Enum.sort_by(entries, fn entry ->
      case entry.queue_position do
        nil -> {1, 0}
        position -> {0, position}
      end
    end)
  end

  defp real_container?(container_id) when is_binary(container_id) do
    container_id != "" and not String.starts_with?(container_id, "task:")
  end

  defp real_container?(_), do: false

  defp value(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> val
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
