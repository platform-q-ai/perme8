defmodule Jarga.Repo.Migrations.AddSlugsToWorkspacesAndProjects do
  use Ecto.Migration

  def up do
    # Add slug field to workspaces table (nullable for now)
    alter table(:workspaces) do
      add :slug, :string
    end

    # Add slug field to projects table (nullable for now)
    alter table(:projects) do
      add :slug, :string
    end

    # Populate slugs for existing records
    execute """
    UPDATE workspaces
    SET slug = lower(regexp_replace(regexp_replace(name, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g'))
    WHERE slug IS NULL
    """

    execute """
    UPDATE projects
    SET slug = lower(regexp_replace(regexp_replace(name, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g'))
    WHERE slug IS NULL
    """

    # Handle potential duplicates by appending a counter
    execute """
    WITH ranked_workspaces AS (
      SELECT id, slug,
             ROW_NUMBER() OVER (PARTITION BY slug ORDER BY inserted_at) as rn
      FROM workspaces
    )
    UPDATE workspaces w
    SET slug = r.slug || '-' || r.rn
    FROM ranked_workspaces r
    WHERE w.id = r.id AND r.rn > 1
    """

    execute """
    WITH ranked_projects AS (
      SELECT id, slug, workspace_id,
             ROW_NUMBER() OVER (PARTITION BY workspace_id, slug ORDER BY inserted_at) as rn
      FROM projects
    )
    UPDATE projects p
    SET slug = r.slug || '-' || r.rn
    FROM ranked_projects r
    WHERE p.id = r.id AND r.rn > 1
    """

    # Now make slug non-nullable
    alter table(:workspaces) do
      modify :slug, :string, null: false
    end

    alter table(:projects) do
      modify :slug, :string, null: false
    end

    # Create unique indexes
    create unique_index(:workspaces, [:slug])
    create unique_index(:projects, [:workspace_id, :slug], name: :projects_workspace_id_slug_index)
  end

  def down do
    drop index(:projects, [:workspace_id, :slug], name: :projects_workspace_id_slug_index)
    drop index(:workspaces, [:slug])

    alter table(:projects) do
      remove :slug
    end

    alter table(:workspaces) do
      remove :slug
    end
  end
end
