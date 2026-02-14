defmodule Jarga.Repo.Migrations.CreateEntitySchemas do
  use Ecto.Migration

  def change do
    create table(:entity_schemas, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(:entity_types, :map, null: false, default: "[]")
      add(:edge_types, :map, null: false, default: "[]")
      add(:version, :integer, null: false, default: 1)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:entity_schemas, [:workspace_id]))
  end
end
