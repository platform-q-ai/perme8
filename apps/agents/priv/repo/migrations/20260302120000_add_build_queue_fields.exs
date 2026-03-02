defmodule Agents.Repo.Migrations.AddBuildQueueFields do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:queue_position, :integer)
      add(:queued_at, :utc_datetime)
    end

    create(index(:sessions_tasks, [:user_id, :queue_position]))
  end
end
