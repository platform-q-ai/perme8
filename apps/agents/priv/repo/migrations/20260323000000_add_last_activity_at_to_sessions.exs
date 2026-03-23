defmodule Agents.Repo.Migrations.AddLastActivityAtToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add(:last_activity_at, :utc_datetime)
    end
  end
end
