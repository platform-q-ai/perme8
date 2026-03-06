defmodule Agents.Repo.Migrations.AddRetryFieldsToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:retry_count, :integer, default: 0, null: false)
      add(:last_retry_at, :utc_datetime, null: true)
      add(:next_retry_at, :utc_datetime, null: true)
    end

    create(
      index(:sessions_tasks, [:user_id, :next_retry_at],
        where: "status = 'queued' AND retry_count > 0",
        name: :sessions_tasks_retry_pending_idx
      )
    )
  end
end
