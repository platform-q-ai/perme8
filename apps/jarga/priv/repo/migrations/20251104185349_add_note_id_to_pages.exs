defmodule Jarga.Repo.Migrations.AddNoteIdToPages do
  use Ecto.Migration

  def change do
    alter table(:pages) do
      add :note_id, references(:notes, type: :uuid, on_delete: :delete_all)
    end

    create index(:pages, [:note_id])
  end
end
