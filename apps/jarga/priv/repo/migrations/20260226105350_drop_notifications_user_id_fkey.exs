defmodule Jarga.Repo.Migrations.DropNotificationsUserIdFkey do
  @moduledoc """
  Drops the foreign key constraint on notifications.user_id.

  The notifications table is now managed by Notifications.Repo (a separate
  Ecto Repo that shares the same database). In the Ecto SQL Sandbox used by
  tests, each Repo gets its own connection/transaction, so cross-repo FK
  constraints fail because the referenced row is invisible to the other
  transaction.

  This follows the same pattern as Agents.Repo, which uses a plain column
  for user_id instead of a foreign key reference. User ownership is enforced
  at the application layer.
  """

  use Ecto.Migration

  def change do
    # Drop the FK constraint but keep the column and index
    drop(constraint(:notifications, "notifications_user_id_fkey"))
  end
end
