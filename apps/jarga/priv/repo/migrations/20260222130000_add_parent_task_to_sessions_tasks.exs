defmodule Jarga.Repo.Migrations.AddParentTaskToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:parent_task_id, references(:sessions_tasks, type: :binary_id, on_delete: :nilify_all))
    end

    create(index(:sessions_tasks, [:parent_task_id]))
  end
end
