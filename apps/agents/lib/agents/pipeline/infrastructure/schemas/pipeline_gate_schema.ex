defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineGateSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_gates" do
    field(:position, :integer)
    field(:type, :string)
    field(:required, :boolean, default: true)
    field(:params, :map, default: %{})

    belongs_to(:pipeline_stage, Agents.Pipeline.Infrastructure.Schemas.PipelineStageSchema)

    timestamps(type: :utc_datetime)
  end

  def changeset(gate, attrs) do
    gate
    |> cast(attrs, [:pipeline_stage_id, :position, :type, :required, :params])
    |> validate_required([:pipeline_stage_id, :position, :type, :required])
  end
end
