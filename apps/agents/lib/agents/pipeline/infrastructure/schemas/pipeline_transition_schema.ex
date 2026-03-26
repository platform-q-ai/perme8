defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineTransitionSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_transitions" do
    field(:position, :integer)
    field(:on, :string)
    field(:to_stage, :string)
    field(:reason, :string)
    field(:params, :map, default: %{})

    belongs_to(:pipeline_stage, Agents.Pipeline.Infrastructure.Schemas.PipelineStageSchema)

    timestamps(type: :utc_datetime)
  end

  def changeset(transition, attrs) do
    transition
    |> cast(attrs, [:pipeline_stage_id, :position, :on, :to_stage, :reason, :params])
    |> validate_required([:pipeline_stage_id, :position, :on])
  end
end
