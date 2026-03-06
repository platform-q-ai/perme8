defmodule Agents.Sessions.Domain.Entities.QueueSnapshot do
  @moduledoc """
  Pure domain entity representing the queue lanes and computed metadata for a user.
  """

  alias Agents.Sessions.Domain.Entities.LaneEntry

  @type lane :: :processing | :warm | :cold | :awaiting_feedback | :retry_pending
  @type lanes :: %{required(lane()) => [LaneEntry.t()]}

  @type metadata :: %{
          concurrency_limit: non_neg_integer(),
          warm_cache_limit: non_neg_integer(),
          running_count: non_neg_integer(),
          available_slots: non_neg_integer(),
          total_queued: non_neg_integer()
        }

  @type t :: %__MODULE__{
          user_id: String.t() | nil,
          lanes: lanes(),
          metadata: metadata(),
          generated_at: DateTime.t()
        }

  @default_lanes %{
    processing: [],
    warm: [],
    cold: [],
    awaiting_feedback: [],
    retry_pending: []
  }

  @default_metadata %{
    concurrency_limit: 2,
    warm_cache_limit: 2,
    running_count: 0,
    available_slots: 2,
    total_queued: 0
  }

  defstruct [:user_id, :generated_at, lanes: @default_lanes, metadata: @default_metadata]

  @doc """
  Creates a queue snapshot with default lanes and metadata.

  Accepts an optional `generated_at` key; defaults to the current UTC time.
  """
  @spec new(map()) :: t()
  def new(attrs, now \\ DateTime.utc_now()) when is_map(attrs) do
    attrs =
      attrs
      |> normalize_lanes()
      |> normalize_metadata()
      |> Map.put_new(:generated_at, now)

    struct(__MODULE__, attrs)
  end

  @doc """
  Returns total queued tasks from warm, cold, and retry lanes.
  """
  @spec total_queued(t()) :: non_neg_integer()
  def total_queued(%__MODULE__{} = snapshot) do
    snapshot.lanes.warm
    |> Kernel.++(snapshot.lanes.cold)
    |> Kernel.++(snapshot.lanes.retry_pending)
    |> length()
  end

  @doc """
  Returns available concurrency slots.
  """
  @spec available_slots(t()) :: integer()
  def available_slots(%__MODULE__{} = snapshot) do
    snapshot.metadata.concurrency_limit - snapshot.metadata.running_count
  end

  @doc """
  Returns tasks for the requested lane atom.
  """
  @spec lane_for(t(), lane()) :: [LaneEntry.t()]
  def lane_for(%__MODULE__{} = snapshot, lane) when is_atom(lane) do
    Map.get(snapshot.lanes, lane, [])
  end

  @doc """
  Converts a snapshot into the legacy queue-state map shape.
  """
  @spec to_legacy_map(t()) :: map()
  def to_legacy_map(%__MODULE__{} = snapshot) do
    %{
      running: snapshot.metadata.running_count,
      queued:
        Enum.map(
          snapshot.lanes.cold ++ snapshot.lanes.warm ++ snapshot.lanes.retry_pending,
          fn e ->
            %{
              id: e.task_id,
              instruction: e.instruction,
              status: e.status,
              queue_position: e.queue_position
            }
          end
        ),
      awaiting_feedback:
        Enum.map(snapshot.lanes.awaiting_feedback, fn e ->
          %{id: e.task_id, instruction: e.instruction, status: e.status}
        end),
      concurrency_limit: snapshot.metadata.concurrency_limit,
      warm_cache_limit: snapshot.metadata.warm_cache_limit,
      warm_task_ids:
        snapshot.lanes.warm
        |> Enum.filter(&LaneEntry.warm?/1)
        |> Enum.map(& &1.task_id),
      warming_task_ids:
        snapshot.lanes.warm
        |> Enum.filter(fn e -> e.warm_state == :warming end)
        |> Enum.map(& &1.task_id)
    }
  end

  defp normalize_lanes(attrs) do
    lanes = Map.merge(default_lanes(), Map.get(attrs, :lanes, %{}))
    Map.put(attrs, :lanes, lanes)
  end

  defp normalize_metadata(attrs) do
    metadata =
      default_metadata()
      |> Map.merge(Map.get(attrs, :metadata, %{}))
      |> Map.put(:available_slots, metadata_available_slots(attrs))
      |> Map.put(:total_queued, metadata_total_queued(attrs))

    Map.put(attrs, :metadata, metadata)
  end

  defp metadata_available_slots(attrs) do
    metadata = Map.merge(default_metadata(), Map.get(attrs, :metadata, %{}))
    metadata.concurrency_limit - metadata.running_count
  end

  defp metadata_total_queued(attrs) do
    lanes = Map.merge(default_lanes(), Map.get(attrs, :lanes, %{}))
    length(lanes.warm) + length(lanes.cold) + length(lanes.retry_pending)
  end

  defp default_lanes do
    @default_lanes
  end

  defp default_metadata do
    @default_metadata
  end
end
