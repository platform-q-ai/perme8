defmodule Jarga.Repo.Migrations.AddSlugToPages do
  use Ecto.Migration

  def change do
    alter table(:pages) do
      add :slug, :string
    end

    create unique_index(:pages, [:workspace_id, :slug])
  end
end
