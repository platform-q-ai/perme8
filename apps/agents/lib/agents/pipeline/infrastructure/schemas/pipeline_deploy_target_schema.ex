defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineDeployTargetSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_deploy_targets" do
    field(:position, :integer)
    field(:target_id, :string)
    field(:environment, :string)
    field(:provider, :string)
    field(:strategy, :string, default: "rolling")
    field(:region, :string)
    field(:config, :map, default: %{})

    belongs_to(:pipeline_config, Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema)

    timestamps(type: :utc_datetime)
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [
      :pipeline_config_id,
      :position,
      :target_id,
      :environment,
      :provider,
      :strategy,
      :region,
      :config
    ])
    |> validate_required([
      :pipeline_config_id,
      :position,
      :target_id,
      :environment,
      :provider,
      :strategy
    ])
  end
end
