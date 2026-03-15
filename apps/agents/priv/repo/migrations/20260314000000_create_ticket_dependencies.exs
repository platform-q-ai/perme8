defmodule Agents.Repo.Migrations.CreateTicketDependencies do
  use Ecto.Migration

  def change do
    create table(:ticket_dependencies) do
      add(:blocker_ticket_id, references(:sessions_project_tickets, on_delete: :delete_all),
        null: false
      )

      add(:blocked_ticket_id, references(:sessions_project_tickets, on_delete: :delete_all),
        null: false
      )

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create(unique_index(:ticket_dependencies, [:blocker_ticket_id, :blocked_ticket_id]))
    create(index(:ticket_dependencies, [:blocked_ticket_id]))
    create(index(:ticket_dependencies, [:blocker_ticket_id]))
  end
end
