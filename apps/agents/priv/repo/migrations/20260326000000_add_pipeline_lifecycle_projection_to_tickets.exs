defmodule Agents.Repo.Migrations.AddPipelineLifecycleProjectionToTickets do
  use Ecto.Migration

  def change do
    alter table(:sessions_project_tickets) do
      add(:lifecycle_owner_run_id, :binary_id)
      add(:lifecycle_reason, :string)
    end

    create(index(:sessions_project_tickets, [:lifecycle_owner_run_id]))
  end
end
