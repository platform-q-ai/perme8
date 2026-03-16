defmodule Agents.Repo.Migrations.CreateSessionInteractions do
  use Ecto.Migration

  def up do
    create table(:session_interactions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:session_id, references(:sessions, type: :uuid, on_delete: :delete_all), null: false)
      add(:task_id, references(:sessions_tasks, type: :uuid, on_delete: :nilify_all))
      add(:type, :string, null: false)
      add(:direction, :string, null: false)
      add(:payload, :map, null: false, default: %{})
      add(:correlation_id, :string)
      add(:status, :string, null: false, default: "pending")

      timestamps(type: :utc_datetime)
    end

    create(index(:session_interactions, [:session_id]))
    create(index(:session_interactions, [:correlation_id]))
    create(index(:session_interactions, [:session_id, :type]))
    create(index(:session_interactions, [:session_id, :status]))
  end

  def down do
    drop(table(:session_interactions))
  end
end
