defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineConfigSchema do
  @moduledoc "Ecto schema for the persisted current pipeline configuration."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_configs" do
    field(:slug, :string)
    field(:yaml, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:slug, :yaml])
    |> validate_required([:slug, :yaml])
    |> unique_constraint(:slug)
  end
end
