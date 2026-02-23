defmodule Agents.Repo.Migrations.CreateSessionsTasks do
  use Ecto.Migration

  def change do
    create table(:sessions_tasks, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:instruction, :text, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:container_id, :string)
      add(:container_port, :integer)
      add(:session_id, :string)
      # user_id references the users table (managed by Jarga/Identity repos).
      # We use a plain column instead of references() because Agents.Repo
      # migrations run before Jarga.Repo migrations (alphabetical order)
      # and the users table may not exist yet. Ownership is enforced at
      # the application layer.
      add(:user_id, :binary_id, null: false)
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
