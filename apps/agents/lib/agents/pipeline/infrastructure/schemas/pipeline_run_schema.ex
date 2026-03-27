defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema do
  @moduledoc "Ecto schema for persisted pipeline runs."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

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

  schema "pipeline_runs" do
    field(:trigger_type, :string)
    field(:trigger_reference, :string)
    field(:task_id, :binary_id)
    field(:session_id, :binary_id)
    field(:pull_request_number, :integer)
    field(:source_branch, :string)
    field(:target_branch, :string)
    field(:status, :string, default: "idle")
    field(:current_stage_id, :string)
    field(:queued_stage_id, :string)
    field(:queue_reason, :string)
    field(:enqueued_at, :utc_datetime)
    field(:remaining_stage_ids, {:array, :string}, default: [])
    field(:attempt_count, :integer, default: 0)
    field(:stage_attempt_counts, :map, default: %{})
    field(:visited_stage_ids, {:array, :string}, default: [])
    field(:stage_results, :map, default: %{})
    field(:failure_reason, :string)
    field(:reopened_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :trigger_type,
      :trigger_reference,
      :task_id,
      :session_id,
      :pull_request_number,
      :source_branch,
      :target_branch,
      :status,
      :current_stage_id,
      :queued_stage_id,
      :queue_reason,
      :enqueued_at,
      :remaining_stage_ids,
      :attempt_count,
      :stage_attempt_counts,
      :visited_stage_ids,
      :stage_results,
      :failure_reason,
      :reopened_at
    ])
    |> validate_required([
      :trigger_type,
      :trigger_reference,
      :status,
      :remaining_stage_ids,
      :stage_results
    ])
    |> validate_inclusion(:status, @statuses)
  end

  def valid_statuses, do: @statuses
end
