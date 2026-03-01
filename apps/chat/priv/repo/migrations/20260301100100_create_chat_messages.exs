defmodule Chat.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS chat_messages (
      id uuid PRIMARY KEY,
      chat_session_id uuid NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
      role varchar(255) NOT NULL,
      content text NOT NULL,
      context_chunks uuid[] DEFAULT '{}',
      inserted_at timestamp(0) without time zone NOT NULL,
      updated_at timestamp(0) without time zone NOT NULL
    )
    """)

    execute(
      "CREATE INDEX IF NOT EXISTS chat_messages_chat_session_id_index ON chat_messages (chat_session_id)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS chat_messages_inserted_at_index ON chat_messages (inserted_at)"
    )
  end

  def down do
    drop(table(:chat_messages))
  end
end
