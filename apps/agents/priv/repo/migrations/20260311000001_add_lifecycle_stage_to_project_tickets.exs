defmodule Agents.Repo.Migrations.AddLifecycleStageToProjectTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:lifecycle_stage, :string, null: false, default: "open")
      add(:lifecycle_stage_entered_at, :utc_datetime)
    end
  end
end
