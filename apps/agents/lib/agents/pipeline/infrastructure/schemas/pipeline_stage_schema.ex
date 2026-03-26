defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineStageSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_stages" do
    field(:position, :integer)
    field(:stage_id, :string)
    field(:type, :string)
    field(:deploy_target, :string)
    field(:schedule, :map)
    field(:config, :map, default: %{})

    belongs_to(:pipeline_config, Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema)

    has_many(:steps, Agents.Pipeline.Infrastructure.Schemas.PipelineStepSchema,
      foreign_key: :pipeline_stage_id
    )

    has_many(:gates, Agents.Pipeline.Infrastructure.Schemas.PipelineGateSchema,
      foreign_key: :pipeline_stage_id
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(stage, attrs) do
    stage
    |> cast(attrs, [
      :pipeline_config_id,
      :position,
      :stage_id,
      :type,
      :deploy_target,
      :schedule,
      :config
    ])
    |> validate_required([:pipeline_config_id, :position, :stage_id, :type])
  end
end
