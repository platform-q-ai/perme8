defmodule Agents.Pipeline.Domain.Entities.PipelineRun do
  @moduledoc "Aggregate root representing a pipeline execution run."

  alias Agents.Pipeline.Domain.Entities.StageResult

  @statuses [
    "idle",
    "queued",
    "running_stage",
    "awaiting_result",
    "passed",
    "blocked",
    "failed",
    "reopen_session"
  ]

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          trigger_type: String.t(),
          trigger_reference: String.t(),
          task_id: Ecto.UUID.t() | nil,
          session_id: Ecto.UUID.t() | nil,
          pull_request_number: integer() | nil,
          source_branch: String.t() | nil,
          target_branch: String.t() | nil,
          status: String.t(),
          current_stage_id: String.t() | nil,
          queued_stage_id: String.t() | nil,
          queue_reason: String.t() | nil,
          enqueued_at: DateTime.t() | nil,
          remaining_stage_ids: [String.t()],
          stage_results: %{optional(String.t()) => StageResult.t()},
          failure_reason: String.t() | nil,
          reopened_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :trigger_type,
    :trigger_reference,
    :task_id,
    :session_id,
    :pull_request_number,
    :source_branch,
    :target_branch,
    :current_stage_id,
    :queued_stage_id,
    :queue_reason,
    :enqueued_at,
    :failure_reason,
    :reopened_at,
    :inserted_at,
    :updated_at,
    status: "idle",
    remaining_stage_ids: [],
    stage_results: %{}
  ]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, normalize_attrs(attrs))

  @spec valid_statuses() :: [String.t()]
  def valid_statuses, do: @statuses

  @spec from_schema(struct()) :: t()
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      trigger_type: schema.trigger_type,
      trigger_reference: schema.trigger_reference,
      task_id: Map.get(schema, :task_id),
      session_id: Map.get(schema, :session_id),
      pull_request_number: Map.get(schema, :pull_request_number),
      source_branch: Map.get(schema, :source_branch),
      target_branch: Map.get(schema, :target_branch),
      status: schema.status,
      current_stage_id: schema.current_stage_id,
      queued_stage_id: Map.get(schema, :queued_stage_id),
      queue_reason: Map.get(schema, :queue_reason),
      enqueued_at: Map.get(schema, :enqueued_at),
      remaining_stage_ids: schema.remaining_stage_ids || [],
      stage_results: decode_stage_results(schema.stage_results || %{}),
      failure_reason: Map.get(schema, :failure_reason),
      reopened_at: Map.get(schema, :reopened_at),
      inserted_at: Map.get(schema, :inserted_at),
      updated_at: Map.get(schema, :updated_at)
    }
  end

  @spec current_or_next_stage_id(t()) :: String.t() | nil
  def current_or_next_stage_id(%__MODULE__{current_stage_id: stage_id}) when is_binary(stage_id),
    do: stage_id

  def current_or_next_stage_id(%__MODULE__{remaining_stage_ids: [stage_id | _]}), do: stage_id
  def current_or_next_stage_id(%__MODULE__{}), do: nil

  @spec pop_next_stage(t()) :: {String.t() | nil, t()}
  def pop_next_stage(%__MODULE__{remaining_stage_ids: [stage_id | rest]} = run) do
    {stage_id, %{run | current_stage_id: stage_id, remaining_stage_ids: rest}}
  end

  def pop_next_stage(%__MODULE__{} = run), do: {run.current_stage_id, run}

  @spec record_stage_result(t(), StageResult.t()) :: t()
  def record_stage_result(%__MODULE__{} = run, %StageResult{} = result) do
    %{run | stage_results: Map.put(run.stage_results, result.stage_id, result)}
  end

  @spec stage_results_to_map(t()) :: map()
  def stage_results_to_map(%__MODULE__{} = run) do
    Map.new(run.stage_results, fn {stage_id, result} -> {stage_id, StageResult.to_map(result)} end)
  end

  defp decode_stage_results(results) when is_map(results) do
    Map.new(results, fn {stage_id, attrs} -> {stage_id, StageResult.from_map(attrs)} end)
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Enum.into(%{})
    |> Map.update(:stage_results, %{}, fn results -> decode_stage_results(results) end)
  end
end
