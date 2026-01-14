defmodule Jarga.Repo.Migrations.RemoveNoteIdFromPages do
  use Ecto.Migration

  def change do
    alter table(:pages) do
      remove :note_id
    end
  end
end
