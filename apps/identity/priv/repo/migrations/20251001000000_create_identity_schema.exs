defmodule Identity.Repo.Migrations.CreateIdentitySchema do
  use Ecto.Migration

  def up do
    # Create workspace_role enum type
    execute("""
    DO $$ BEGIN
      CREATE TYPE workspace_role AS ENUM ('owner', 'admin', 'member', 'guest');
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;
    """)

    # Create users table
    create_if_not_exists table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true, null: false)
      add(:first_name, :string, null: false)
      add(:last_name, :string, null: false)
      add(:email, :string, null: false)
      add(:password_hash, :string)
      add(:role, :string)
      add(:date_created, :naive_datetime)
      add(:last_login, :naive_datetime)
      add(:status, :string)
      add(:avatar_url, :string)
    end

    create_if_not_exists(unique_index(:users, [:email]))

    # Create workspaces table
    create_if_not_exists table(:workspaces, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:name, :text, null: false)
      add(:description, :text)
      add(:color, :string)
      add(:is_archived, :boolean, default: false)

      timestamps(type: :utc_datetime)
    end

    # Create workspace_members table
    create_if_not_exists table(:workspace_members, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)

      add(:workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:user_id, references(:users, type: :binary_id, on_delete: :nilify_all))
      add(:email, :string, null: false)
      add(:role, :workspace_role, null: false, default: fragment("'member'::workspace_role"))
      add(:invited_by, references(:users, type: :binary_id, on_delete: :nilify_all))
      add(:invited_at, :utc_datetime)
      add(:joined_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists(index(:workspace_members, [:workspace_id]))
    create_if_not_exists(index(:workspace_members, [:user_id]))
    create_if_not_exists(index(:workspace_members, [:email]))
    create_if_not_exists(unique_index(:workspace_members, [:workspace_id, :email]))

    # Create workspace_invitations table
    create_if_not_exists table(:workspace_invitations, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)

      add(:workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:email, :string, null: false)
      add(:clerk_invitation_id, :string)
      add(:role, :workspace_role, null: false, default: fragment("'member'::workspace_role"))
      add(:invited_by, references(:users, type: :binary_id, on_delete: :nilify_all), null: false)
      add(:invited_at, :utc_datetime, null: false)
      add(:expires_at, :utc_datetime, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:accepted_at, :utc_datetime)
      add(:accepted_by, references(:users, type: :binary_id, on_delete: :nilify_all))
      add(:metadata, :jsonb)
    end

    create_if_not_exists(index(:workspace_invitations, [:workspace_id]))
    create_if_not_exists(index(:workspace_invitations, [:email]))
    create_if_not_exists(index(:workspace_invitations, [:status]))
  end

  def down do
    drop_if_exists(table(:workspace_invitations))
    drop_if_exists(table(:workspace_members))
    drop_if_exists(table(:workspaces))
    drop_if_exists(table(:users))

    execute("DROP TYPE IF EXISTS workspace_role;")
  end
end
