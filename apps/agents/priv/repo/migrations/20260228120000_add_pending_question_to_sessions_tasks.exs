defmodule Agents.Repo.Migrations.AddPendingQuestionToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:pending_question, :map)
    end
  end
end
