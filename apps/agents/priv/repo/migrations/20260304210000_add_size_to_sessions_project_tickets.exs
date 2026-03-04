defmodule Agents.Repo.Migrations.AddSizeToSessionsProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:size, :string)
    end
  end
end
