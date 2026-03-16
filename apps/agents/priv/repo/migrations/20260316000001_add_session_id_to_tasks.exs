defmodule Agents.Repo.Migrations.AddSessionIdToTasks do
  use Ecto.Migration

  def up do
    alter table(:sessions_tasks) do
      add(:session_ref_id, references(:sessions, type: :uuid, on_delete: :nilify_all))
    end

    create(index(:sessions_tasks, [:session_ref_id]))
  end

  def down do
    drop(index(:sessions_tasks, [:session_ref_id]))

    alter table(:sessions_tasks) do
      remove(:session_ref_id)
    end
  end
end
