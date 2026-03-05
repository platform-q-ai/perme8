defmodule Agents.Repo.Migrations.DropAgentsCrossAppFkConstraints do
  @moduledoc """
  Drops foreign key constraints that reference Identity-owned tables (users, workspaces).

  This aligns the Agents app with the Standalone App Principle: domain apps must not
  have cross-app schema references. Referential integrity for cross-app references
  is enforced at the application layer, not the database layer.

  Mirrors the pattern established by Chat in 20260301100200_drop_chat_fk_constraints.
  """
  use Ecto.Migration

  def up do
    execute("ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_user_id_fkey")

    execute(
      "ALTER TABLE workspace_agents DROP CONSTRAINT IF EXISTS workspace_agents_workspace_id_fkey"
    )
  end

  def down do
    # Intentionally not restored -- re-adding cross-app FK constraints would violate
    # the Standalone App Principle.
    :ok
  end
end
