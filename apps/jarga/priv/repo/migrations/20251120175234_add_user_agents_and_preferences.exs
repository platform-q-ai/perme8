defmodule Jarga.Repo.Migrations.AddUserAgentsAndPreferences do
  use Ecto.Migration

  def change do
    # Create user-scoped agents table
    create table(:agents, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:system_prompt, :text)
      add(:temperature, :float, default: 0.7, null: false)
      add(:model, :string)
      add(:input_token_cost, :decimal, precision: 20, scale: 10)
      add(:cached_input_token_cost, :decimal, precision: 20, scale: 10)
      add(:output_token_cost, :decimal, precision: 20, scale: 10)
      add(:cached_output_token_cost, :decimal, precision: 20, scale: 10)
      add(:visibility, :string, default: "PRIVATE", null: false)
      add(:enabled, :boolean, default: true, null: false)

      timestamps(type: :utc_datetime)
    end

    # Create indexes on agents table
    create(index(:agents, [:user_id]))

    # Create check constraint for visibility enum
    create(
      constraint(:agents, :visibility_must_be_valid, check: "visibility IN ('PRIVATE', 'SHARED')")
    )

    # Create workspace_agents join table (many-to-many relationship)
    create table(:workspace_agents, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:workspace_id, references(:workspaces, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:agent_id, references(:agents, type: :uuid, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime)
    end

    # Create unique constraint to prevent duplicate agent-workspace associations
    create(unique_index(:workspace_agents, [:workspace_id, :agent_id]))

    # Create indexes for performance
    create(index(:workspace_agents, [:agent_id]))

    # Add user preferences column if it doesn't already exist
    # (Identity app may have already created this column)
    execute(
      """
      DO $$ BEGIN
        IF NOT EXISTS(SELECT 1 FROM information_schema.columns
                      WHERE table_name='users' AND column_name='preferences')
        THEN
          ALTER TABLE users ADD COLUMN preferences jsonb NOT NULL DEFAULT '{}';
        END IF;
      END $$;
      """,
      """
      DO $$ BEGIN
        IF EXISTS(SELECT 1 FROM information_schema.columns
                  WHERE table_name='users' AND column_name='preferences')
        THEN
          ALTER TABLE users DROP COLUMN preferences;
        END IF;
      END $$;
      """
    )

    create_if_not_exists(index(:users, [:preferences], using: :gin))
  end
end
