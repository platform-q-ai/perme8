defmodule Jarga.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    # The users table already exists with user_id as varchar primary key
    # We need to add the new authentication-related columns
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    # Rename password_hash to hashed_password for consistency with phx.gen.auth
    # Only rename if password_hash exists and hashed_password doesn't
    execute """
    DO $$ BEGIN
      IF EXISTS(SELECT 1 FROM information_schema.columns
                WHERE table_name='users' AND column_name='password_hash')
      AND NOT EXISTS(SELECT 1 FROM information_schema.columns
                     WHERE table_name='users' AND column_name='hashed_password')
      THEN
        ALTER TABLE users RENAME COLUMN password_hash TO hashed_password;
      END IF;
    END $$;
    """, """
    DO $$ BEGIN
      IF EXISTS(SELECT 1 FROM information_schema.columns
                WHERE table_name='users' AND column_name='hashed_password')
      AND NOT EXISTS(SELECT 1 FROM information_schema.columns
                     WHERE table_name='users' AND column_name='password_hash')
      THEN
        ALTER TABLE users RENAME COLUMN hashed_password TO password_hash;
      END IF;
    END $$;
    """

    # Add confirmed_at column for email confirmation if it doesn't exist
    execute """
    DO $$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM information_schema.columns
                    WHERE table_name='users' AND column_name='confirmed_at')
      THEN
        ALTER TABLE users ADD COLUMN confirmed_at timestamp with time zone;
      END IF;
    END $$;
    """, """
    DO $$ BEGIN
      IF EXISTS(SELECT 1 FROM information_schema.columns
                WHERE table_name='users' AND column_name='confirmed_at')
      THEN
        ALTER TABLE users DROP COLUMN confirmed_at;
      END IF;
    END $$;
    """

    # Ensure email has unique constraint (skip if already exists)
    create_if_not_exists unique_index(:users, [:email], where: "email IS NOT NULL")

    # Create tokens table for authentication tokens (session, email confirmation, etc.)
    create_if_not_exists table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create_if_not_exists index(:users_tokens, [:user_id])
    create_if_not_exists unique_index(:users_tokens, [:context, :token])
  end
end
