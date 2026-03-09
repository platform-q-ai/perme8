defmodule Agents.Repo.Migrations.AddLifecycleStateToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:lifecycle_state, :string, default: "idle")
    end

    create(index(:sessions_tasks, [:user_id, :lifecycle_state]))

    execute(
      """
      UPDATE sessions_tasks SET lifecycle_state = CASE
        WHEN status = 'completed' THEN 'completed'
        WHEN status = 'failed' THEN 'failed'
        WHEN status = 'cancelled' THEN 'cancelled'
        WHEN status = 'running' THEN 'running'
        WHEN status = 'starting' THEN 'starting'
        WHEN status = 'awaiting_feedback' THEN 'awaiting_feedback'
        WHEN status = 'pending' THEN 'pending'
        WHEN status = 'queued' AND container_id IS NOT NULL AND container_id != '' AND container_id NOT LIKE 'task:%' THEN 'queued_warm'
        WHEN status = 'queued' THEN 'queued_cold'
        ELSE 'idle'
      END WHERE lifecycle_state IS NULL OR lifecycle_state = 'idle'
      """,
      "SELECT 1"
    )
  end
end
