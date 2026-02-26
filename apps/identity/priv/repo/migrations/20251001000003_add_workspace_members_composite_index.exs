defmodule Identity.Repo.Migrations.AddWorkspaceMembersCompositeIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:workspace_members, [:workspace_id, :user_id]))
  end
end
