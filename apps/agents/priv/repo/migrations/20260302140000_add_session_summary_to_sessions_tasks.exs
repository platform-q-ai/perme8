defmodule Agents.Repo.Migrations.AddSessionSummaryToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:session_summary, :map)
    end
  end
end
