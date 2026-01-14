defmodule Jarga.Repo.Migrations.CreatePageComponents do
  use Ecto.Migration

  def change do
    create table(:page_components, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :page_id, references(:pages, type: :binary_id, on_delete: :delete_all), null: false

      # Polymorphic association fields
      add :component_type, :string, null: false
      add :component_id, :binary_id, null: false

      # Position for ordering components on the page
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:page_components, [:page_id])
    create index(:page_components, [:component_type, :component_id])
    create unique_index(:page_components, [:page_id, :component_type, :component_id])
  end
end
