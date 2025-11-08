defmodule Jarga.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :chat_session_id, references(:chat_sessions, type: :binary_id, on_delete: :delete_all),
        null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :context_chunks, {:array, :binary_id}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:chat_session_id])
    create index(:chat_messages, [:inserted_at])
  end
end
