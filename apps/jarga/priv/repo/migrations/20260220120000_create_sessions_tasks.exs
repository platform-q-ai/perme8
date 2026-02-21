defmodule Jarga.Repo.Migrations.CreateSessionsTasks do
  use Ecto.Migration

  def change do
    create table(:sessions_tasks, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:instruction, :text, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:container_id, :string)
      add(:container_port, :integer)
      add(:session_id, :string)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:error, :text)
      add(:started_at, :utc_datetime)
      add(:completed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:sessions_tasks, [:user_id]))
    create(index(:sessions_tasks, [:status]))
    create(index(:sessions_tasks, [:user_id, :inserted_at]))
    create(index(:sessions_tasks, [:user_id, :status]))
  end
end
