defmodule Agents.Repo.Migrations.CreateSessionsProjectTickets do
  use Ecto.Migration

  def change do
    create table(:sessions_project_tickets) do
      add(:number, :integer, null: false)
      add(:external_id, :string)
      add(:title, :string, null: false)
      add(:status, :string)
      add(:priority, :string)
      add(:labels, {:array, :string}, null: false, default: [])
      add(:url, :string)
      add(:sync_state, :string, null: false, default: "synced")
      add(:last_synced_at, :utc_datetime)
      add(:last_sync_error, :text)
      add(:remote_updated_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:sessions_project_tickets, [:number]))
    create(index(:sessions_project_tickets, [:status]))
    create(index(:sessions_project_tickets, [:sync_state]))
  end
end
