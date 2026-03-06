defmodule Agents.Repo.Migrations.ResetTicketPositions do
  @moduledoc """
  Resets all ticket positions to 0 so that the default ordering falls back to
  `created_at DESC` (newest first). Adds a `created_at` column sourced from the
  GitHub issue creation date, defaulting to `inserted_at` until the next sync
  populates the real value. Drag-and-drop reordering still works — positions are
  assigned on drag, but the baseline is now creation-date order.
  """

  use Ecto.Migration

  def up do
    alter table(:sessions_project_tickets) do
      add(:created_at, :utc_datetime)
    end

    # Seed created_at from inserted_at so existing tickets have a non-null value
    # until the next GitHub sync populates the real creation date.
    execute("UPDATE sessions_project_tickets SET created_at = inserted_at")

    alter table(:sessions_project_tickets) do
      modify(:created_at, :utc_datetime, null: false)
    end

    create(index(:sessions_project_tickets, [:created_at]))

    # Reset all positions so ordering falls back to created_at DESC
    execute("UPDATE sessions_project_tickets SET position = 0")
  end

  def down do
    drop_if_exists(index(:sessions_project_tickets, [:created_at]))

    alter table(:sessions_project_tickets) do
      remove(:created_at)
    end
  end
end
