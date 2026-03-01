defmodule Chat.Repo.Migrations.DropChatFkConstraints do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_user_id_fkey")

    execute("ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_workspace_id_fkey")

    execute("ALTER TABLE chat_sessions DROP CONSTRAINT IF EXISTS chat_sessions_project_id_fkey")
  end

  def down do
    :ok
  end
end
