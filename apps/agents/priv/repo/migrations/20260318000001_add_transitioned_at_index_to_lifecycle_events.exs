defmodule Agents.Repo.Migrations.AddTransitionedAtIndexToLifecycleEvents do
  use Ecto.Migration

  def change do
    create(index(:sessions_ticket_lifecycle_events, [:transitioned_at]))
  end
end
