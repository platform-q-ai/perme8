defmodule Identity.Repo.Migrations.AddSlugToWorkspaces do
  use Ecto.Migration

  def up do
    # Add slug column to workspaces if it doesn't already exist
    execute("""
    DO $$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM information_schema.columns
                    WHERE table_name='workspaces' AND column_name='slug')
      THEN
        ALTER TABLE workspaces ADD COLUMN slug varchar;

        -- Populate slugs for existing records
        UPDATE workspaces
        SET slug = lower(regexp_replace(regexp_replace(name, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g'))
        WHERE slug IS NULL;

        -- Handle potential duplicates by appending a counter
        WITH ranked_workspaces AS (
          SELECT id, slug,
                 ROW_NUMBER() OVER (PARTITION BY slug ORDER BY inserted_at) as rn
          FROM workspaces
        )
        UPDATE workspaces w
        SET slug = r.slug || '-' || r.rn
        FROM ranked_workspaces r
        WHERE w.id = r.id AND r.rn > 1;

        -- Make non-nullable
        ALTER TABLE workspaces ALTER COLUMN slug SET NOT NULL;
      END IF;
    END $$;
    """)

    create_if_not_exists(unique_index(:workspaces, [:slug]))
  end

  def down do
    drop_if_exists(index(:workspaces, [:slug]))

    execute("""
    DO $$ BEGIN
      IF EXISTS(SELECT 1 FROM information_schema.columns
                WHERE table_name='workspaces' AND column_name='slug')
      THEN
        ALTER TABLE workspaces DROP COLUMN slug;
      END IF;
    END $$;
    """)
  end
end
