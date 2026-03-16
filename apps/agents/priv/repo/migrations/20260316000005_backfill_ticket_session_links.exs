defmodule Agents.Repo.Migrations.BackfillTicketSessionLinks do
  use Ecto.Migration

  def up do
    # Backfill: for tickets that have task_id, look up the task's session_ref_id
    # and set the ticket's session_id accordingly
    execute("""
    UPDATE sessions_project_tickets pt
    SET session_id = t.session_ref_id
    FROM sessions_tasks t
    WHERE pt.task_id = t.id
    AND t.session_ref_id IS NOT NULL
    AND pt.session_id IS NULL
    """)
  end

  def down do
    execute("UPDATE sessions_project_tickets SET session_id = NULL")
  end
end
