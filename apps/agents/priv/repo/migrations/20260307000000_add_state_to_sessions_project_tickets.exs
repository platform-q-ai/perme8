defmodule Agents.Repo.Migrations.AddStateToSessionsProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:state, :string, default: "open", null: false)
    end

    create(index(:sessions_project_tickets, [:state]))
  end
end
