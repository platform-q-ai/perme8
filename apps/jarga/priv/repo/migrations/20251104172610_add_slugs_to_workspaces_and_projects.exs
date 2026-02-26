defmodule Jarga.Repo.Migrations.AddSlugsToWorkspacesAndProjects do
  use Ecto.Migration

  def up do
    # Add slug field to workspaces table if it doesn't already exist
    # (Identity app may have already created this column)
    execute("""
    DO $$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM information_schema.columns
                    WHERE table_name='workspaces' AND column_name='slug')
      THEN
        ALTER TABLE workspaces ADD COLUMN slug varchar;
      END IF;
    END $$;
    """)

    # Add slug field to projects table (nullable for now)
    execute("""
    DO $$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM information_schema.columns
                    WHERE table_name='projects' AND column_name='slug')
      THEN
        ALTER TABLE projects ADD COLUMN slug varchar;
      END IF;
    END $$;
    """)

    # Populate slugs for existing records
    execute("""
    UPDATE workspaces
    SET slug = lower(regexp_replace(regexp_replace(name, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g'))
    WHERE slug IS NULL
    """)

    execute("""
    UPDATE projects
    SET slug = lower(regexp_replace(regexp_replace(name, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g'))
    WHERE slug IS NULL
    """)

    # Handle potential duplicates by appending a counter
    execute("""
    WITH ranked_workspaces AS (
      SELECT id, slug,
             ROW_NUMBER() OVER (PARTITION BY slug ORDER BY inserted_at) as rn
      FROM workspaces
    )
    UPDATE workspaces w
    SET slug = r.slug || '-' || r.rn
    FROM ranked_workspaces r
    WHERE w.id = r.id AND r.rn > 1
    """)

    execute("""
    WITH ranked_projects AS (
      SELECT id, slug, workspace_id,
             ROW_NUMBER() OVER (PARTITION BY workspace_id, slug ORDER BY inserted_at) as rn
      FROM projects
    )
    UPDATE projects p
    SET slug = r.slug || '-' || r.rn
    FROM ranked_projects r
    WHERE p.id = r.id AND r.rn > 1
    """)

    # Now make slug non-nullable (safe to run even if already NOT NULL)
    execute("ALTER TABLE workspaces ALTER COLUMN slug SET NOT NULL")
    execute("ALTER TABLE projects ALTER COLUMN slug SET NOT NULL")

    # Create unique indexes (use IF NOT EXISTS)
    create_if_not_exists(unique_index(:workspaces, [:slug]))

    create_if_not_exists(
      unique_index(:projects, [:workspace_id, :slug], name: :projects_workspace_id_slug_index)
    )
  end

  def down do
    drop_if_exists(
      index(:projects, [:workspace_id, :slug], name: :projects_workspace_id_slug_index)
    )

    drop_if_exists(index(:workspaces, [:slug]))

    alter table(:projects) do
      remove(:slug)
    end

    alter table(:workspaces) do
      remove(:slug)
    end
  end
end
