defmodule Agents.Repo.Migrations.AddBodyToSessionsProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:body, :text)
    end
  end
end
