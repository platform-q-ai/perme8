defmodule Agents.Repo.Migrations.AddImageToSessionsTasks do
  use Ecto.Migration

  def change do
    alter table(:sessions_tasks) do
      add(:image, :string, default: "perme8-opencode")
    end
  end
end
