defmodule Agents.Repo.Migrations.AddTaskIdToProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:task_id, references(:sessions_tasks, type: :uuid, on_delete: :nilify_all))
    end

    create(index(:sessions_project_tickets, [:task_id]))
  end
end
