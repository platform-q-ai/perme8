defmodule Agents.Repo.Migrations.AddSessionIdToProjectTickets do
  use Ecto.Migration

  def up do
    alter table(:sessions_project_tickets) do
      add(:session_id, references(:sessions, type: :uuid, on_delete: :nilify_all))
    end

    create(index(:sessions_project_tickets, [:session_id]))
  end

  def down do
    drop(index(:sessions_project_tickets, [:session_id]))

    alter table(:sessions_project_tickets) do
      remove(:session_id)
    end
  end
end
