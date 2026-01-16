defmodule Jarga.Repo.Migrations.AddYjsStateToNotes do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add :yjs_state, :binary
    end
  end
end
