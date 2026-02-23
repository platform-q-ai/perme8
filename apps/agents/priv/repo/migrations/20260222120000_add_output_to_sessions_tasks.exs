defmodule Agents.Repo.Migrations.AddOutputToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:output, :text)
    end
  end
end
