defmodule Agents.Repo.Migrations.AddPositionToSessionsProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:position, :integer, default: 0, null: false)
    end

    create(index(:sessions_project_tickets, [:position]))
  end
end
