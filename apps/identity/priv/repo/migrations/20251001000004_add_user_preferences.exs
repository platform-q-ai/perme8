defmodule Identity.Repo.Migrations.AddUserPreferences do
  use Ecto.Migration

  def up do
    # Add preferences column if it doesn't already exist
    execute("""
    DO $$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM information_schema.columns
                    WHERE table_name='users' AND column_name='preferences')
      THEN
        ALTER TABLE users ADD COLUMN preferences jsonb NOT NULL DEFAULT '{}';
      END IF;
    END $$;
    """)

    create_if_not_exists(index(:users, [:preferences], using: :gin))
  end

  def down do
    drop_if_exists(index(:users, [:preferences]))

    execute("""
    DO $$ BEGIN
      IF EXISTS(SELECT 1 FROM information_schema.columns
                WHERE table_name='users' AND column_name='preferences')
      THEN
        ALTER TABLE users DROP COLUMN preferences;
      END IF;
    END $$;
    """)
  end
end
