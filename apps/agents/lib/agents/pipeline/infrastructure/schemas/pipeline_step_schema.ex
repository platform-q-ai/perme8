defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineStepSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_steps" do
    field(:position, :integer)
    field(:name, :string)
    field(:run, :string)
    field(:timeout_seconds, :integer)
    field(:retries, :integer, default: 0)
    field(:conditions, :string)
    field(:env, :map, default: %{})

    belongs_to(:pipeline_stage, Agents.Pipeline.Infrastructure.Schemas.PipelineStageSchema)

    timestamps(type: :utc_datetime)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [
      :pipeline_stage_id,
      :position,
      :name,
      :run,
      :timeout_seconds,
      :retries,
      :conditions,
      :env
    ])
    |> validate_required([:pipeline_stage_id, :position, :name, :run, :retries])
  end
end
