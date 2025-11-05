defmodule Jarga.Repo.Migrations.AddPerformanceIndexesToPages do
  use Ecto.Migration

  def change do
    # CRITICAL: Composite index for viewable_by_user JOIN condition
    # Speeds up: left_join on wm.workspace_id == p.workspace_id and wm.user_id == ^user_id
    # Used in: Pages.Queries.viewable_by_user/2
    create_if_not_exists index(:workspace_members, [:workspace_id, :user_id])

    # CRITICAL: Composite index for page ordering
    # Speeds up: ORDER BY is_pinned DESC, updated_at DESC
    # Used in: Pages.Queries.ordered/1 (called on workspace/project show pages)
    create_if_not_exists index(:pages, [:is_pinned, :updated_at])

    # IMPORTANT: Composite index for filtering public pages by workspace
    # Speeds up: WHERE workspace_id = X AND is_public = true
    # Used in: Pages.Queries.viewable_by_user/2
    create_if_not_exists index(:pages, [:workspace_id, :is_public])

    # OPTIONAL: Composite index for project pages with ordering
    # Speeds up: WHERE project_id = X ORDER BY is_pinned DESC, updated_at DESC
    # Used in: Pages.list_pages_for_project/3
    create_if_not_exists index(:pages, [:project_id, :is_pinned, :updated_at])
  end
end
