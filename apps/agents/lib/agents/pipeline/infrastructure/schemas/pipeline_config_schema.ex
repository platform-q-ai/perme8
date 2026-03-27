defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema do
  @moduledoc "Ecto schema for the persisted current pipeline configuration."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_configs" do
    field(:slug, :string)
    field(:version, :integer)
    field(:name, :string)
    field(:description, :string)

    has_many(:stages, Agents.Pipeline.Infrastructure.Schemas.PipelineStageSchema,
      foreign_key: :pipeline_config_id
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:slug, :version, :name, :description])
    |> validate_required([:slug, :version, :name])
    |> unique_constraint(:slug)
  end
end
