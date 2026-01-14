defmodule Jarga.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :title, :string, null: false
      add :body, :text
      add :data, :map, default: %{}, null: false
      add :read, :boolean, default: false, null: false
      add :read_at, :utc_datetime
      add :action_taken_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read])
    create index(:notifications, [:type])
    create index(:notifications, [:inserted_at])
  end
end
