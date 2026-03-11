defmodule Agents.Repo.Migrations.CreateSessionsTicketLifecycleEvents do
  use Ecto.Migration

  def change do
    create table(:sessions_ticket_lifecycle_events) do
      add(
        :ticket_id,
        references(:sessions_project_tickets, on_delete: :delete_all),
        null: false
      )

      add(:from_stage, :string)
      add(:to_stage, :string, null: false)
      add(:transitioned_at, :utc_datetime, null: false)
      add(:trigger, :string, null: false, default: "system")

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create(index(:sessions_ticket_lifecycle_events, [:ticket_id]))
    create(index(:sessions_ticket_lifecycle_events, [:ticket_id, :transitioned_at]))
  end
end
