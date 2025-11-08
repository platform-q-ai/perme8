defmodule Jarga.Repo.Migrations.CreateChatSessions do
  use Ecto.Migration

  def change do
    create table(:chat_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_sessions, [:user_id])
    create index(:chat_sessions, [:workspace_id])
    create index(:chat_sessions, [:project_id])
    create index(:chat_sessions, [:inserted_at])
  end
end
