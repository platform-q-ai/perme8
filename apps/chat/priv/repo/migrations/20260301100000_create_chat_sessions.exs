defmodule Chat.Repo.Migrations.CreateChatSessions do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS chat_sessions (
      id uuid PRIMARY KEY,
      title varchar(255),
      user_id uuid NOT NULL,
      workspace_id uuid,
      project_id uuid,
      inserted_at timestamp(0) without time zone NOT NULL,
      updated_at timestamp(0) without time zone NOT NULL
    )
    """)

    execute("CREATE INDEX IF NOT EXISTS chat_sessions_user_id_index ON chat_sessions (user_id)")

    execute(
      "CREATE INDEX IF NOT EXISTS chat_sessions_workspace_id_index ON chat_sessions (workspace_id)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS chat_sessions_project_id_index ON chat_sessions (project_id)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS chat_sessions_inserted_at_index ON chat_sessions (inserted_at)"
    )
  end

  def down do
    drop(table(:chat_sessions))
  end
end
