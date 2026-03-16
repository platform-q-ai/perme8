defmodule Agents.Repo.Migrations.CreateSessionsTable do
  use Ecto.Migration

  def up do
    create table(:sessions, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:user_id, :uuid, null: false)
      add(:title, :text)
      add(:status, :string, null: false, default: "active")
      add(:container_id, :string)
      add(:container_port, :integer)
      add(:container_status, :string, default: "pending")
      add(:image, :string, default: "perme8-opencode")
      add(:sdk_session_id, :string)
      add(:paused_at, :utc_datetime)
      add(:resumed_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(index(:sessions, [:user_id]))
    create(index(:sessions, [:container_id]))
  end

  def down do
    drop(table(:sessions))
  end
end
