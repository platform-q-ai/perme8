defmodule Agents.Repo.Migrations.AddParentTicketIdToProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:parent_ticket_id, references(:sessions_project_tickets, on_delete: :nilify_all))
    end

    create(index(:sessions_project_tickets, [:parent_ticket_id]))
  end
end
