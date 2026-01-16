defmodule Jarga.Repo.Migrations.CreateInitialSchema do
  use Ecto.Migration

  def up do
    # Create custom types
    execute """
    DO $$ BEGIN
      CREATE TYPE workspace_role AS ENUM ('owner', 'admin', 'member', 'guest');
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;
    """

    # Create users table with standard id primary key
    create_if_not_exists table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string
      add :role, :string
      add :date_created, :naive_datetime
      add :last_login, :naive_datetime
      add :status, :string
      add :avatar_url, :string
    end

    create_if_not_exists unique_index(:users, [:email])

    # Create workspaces table
    create_if_not_exists table(:workspaces, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :text, null: false
      add :description, :text
      add :color, :string
      add :is_archived, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    # Create workspace_members table
    create_if_not_exists table(:workspace_members, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :email, :string, null: false
      add :role, :workspace_role, null: false, default: fragment("'member'::workspace_role")
      add :invited_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :invited_at, :utc_datetime
      add :joined_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:workspace_members, [:workspace_id])
    create_if_not_exists index(:workspace_members, [:user_id])
    create_if_not_exists index(:workspace_members, [:email])
    create_if_not_exists unique_index(:workspace_members, [:workspace_id, :email])

    # Create workspace_invitations table
    create_if_not_exists table(:workspace_invitations, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all), null: false
      add :email, :string, null: false
      add :clerk_invitation_id, :string
      add :role, :workspace_role, null: false, default: fragment("'member'::workspace_role")
      add :invited_by, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :invited_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"
      add :accepted_at, :utc_datetime
      add :accepted_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :metadata, :jsonb
    end

    create_if_not_exists index(:workspace_invitations, [:workspace_id])
    create_if_not_exists index(:workspace_invitations, [:email])
    create_if_not_exists index(:workspace_invitations, [:status])

    # Create projects table
    create_if_not_exists table(:projects, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all)
      add :name, :text, null: false
      add :description, :text
      add :color, :string
      add :is_default, :boolean, default: false
      add :is_archived, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:projects, [:user_id])
    create_if_not_exists index(:projects, [:workspace_id])
    create_if_not_exists index(:projects, [:workspace_id, :user_id])

    # Create notes table
    create_if_not_exists table(:notes, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all), null: false
      add :project_id, references(:projects, type: :uuid, on_delete: :nilify_all)
      add :note_content, :jsonb

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:notes, [:user_id])
    create_if_not_exists index(:notes, [:workspace_id])
    create_if_not_exists index(:notes, [:project_id])

    # Create pages table
    create_if_not_exists table(:pages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all), null: false
      add :project_id, references(:projects, type: :uuid, on_delete: :nilify_all)
      add :title, :text, null: false
      add :is_public, :boolean, default: false
      add :is_pinned, :boolean, default: false
      add :created_by, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:pages, [:user_id])
    create_if_not_exists index(:pages, [:workspace_id])
    create_if_not_exists index(:pages, [:project_id])

    # Create page_component_embeds table
    create_if_not_exists table(:page_component_embeds, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :page_id, references(:pages, type: :uuid, on_delete: :delete_all), null: false
      add :component_type, :text, null: false
      add :component_id, :text, null: false
      add :order, :integer, null: false

      add :created_at, :utc_datetime, null: false
    end

    create_if_not_exists index(:page_component_embeds, [:page_id])
    create_if_not_exists index(:page_component_embeds, [:component_type])
    create_if_not_exists index(:page_component_embeds, [:component_id])

    # Create sheets table
    create_if_not_exists table(:sheets, primary_key: false) do
      add :id, :text, primary_key: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all), null: false
      add :project_id, references(:projects, type: :uuid, on_delete: :nilify_all)
      add :title, :text, null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :configuration, :jsonb

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:sheets, [:user_id])
    create_if_not_exists index(:sheets, [:workspace_id])
    create_if_not_exists index(:sheets, [:project_id])

    # Create sheet_data_types table
    create_if_not_exists table(:sheet_data_types, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :text, null: false
      add :type, :text, null: false
      add :values, :jsonb
      add :default_value, :jsonb

      add :created_at, :utc_datetime, null: false
    end

    create_if_not_exists index(:sheet_data_types, [:type])

    # Create sheet_rows table
    create_if_not_exists table(:sheet_rows, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all), null: false
      add :sheet_id, :text, null: false
      add :project_id, references(:projects, type: :uuid, on_delete: :nilify_all)
      add :page_id, references(:pages, type: :uuid, on_delete: :nilify_all)
      add :title, :text
      add :data, :jsonb
      add :order, :integer, null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :assigned_to_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:sheet_rows, [:workspace_id])
    create_if_not_exists index(:sheet_rows, [:sheet_id])
    create_if_not_exists index(:sheet_rows, [:project_id])
    create_if_not_exists index(:sheet_rows, [:page_id])
    create_if_not_exists index(:sheet_rows, [:assigned_to_id])
  end

  def down do
    drop_if_exists table(:sheet_rows)
    drop_if_exists table(:sheet_data_types)
    drop_if_exists table(:sheets)
    drop_if_exists table(:page_component_embeds)
    drop_if_exists table(:pages)
    drop_if_exists table(:notes)
    drop_if_exists table(:projects)
    drop_if_exists table(:workspace_invitations)
    drop_if_exists table(:workspace_members)
    drop_if_exists table(:workspaces)
    drop_if_exists table(:users)

    execute "DROP TYPE IF EXISTS workspace_role;"
  end
end
