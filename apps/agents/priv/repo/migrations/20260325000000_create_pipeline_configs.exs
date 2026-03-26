defmodule Agents.Repo.Migrations.CreatePipelineConfigs do
  use Ecto.Migration

  def change do
    create table(:pipeline_configs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:slug, :string, null: false)
      add(:yaml, :text, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:pipeline_configs, [:slug]))
  end
end
