defmodule Jarga.Repo.Migrations.DropAgentsCrossAppFkConstraints do
  @moduledoc """
  Drops foreign key constraints on agents-owned tables that reference
  Identity-owned tables (users, workspaces).

  The agents and workspace_agents tables are now managed by Agents.Repo
  (a separate Ecto Repo that shares the same database). Cross-app FK
  constraints fail in the Ecto SQL Sandbox because each Repo gets its
  own connection/transaction, making referenced rows invisible.

  This follows the pattern established in 20260226105350_drop_notifications_user_id_fkey.
  Referential integrity is enforced at the application layer.
  """

  use Ecto.Migration

  def change do
    # Drop FK constraints but keep the columns and indexes
    drop_if_exists(constraint(:agents, "agents_user_id_fkey"))
    drop_if_exists(constraint(:workspace_agents, "workspace_agents_workspace_id_fkey"))
  end
end
