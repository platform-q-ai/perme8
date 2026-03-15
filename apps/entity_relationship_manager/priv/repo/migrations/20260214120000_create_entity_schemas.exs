defmodule EntityRelationshipManager.Repo.Migrations.CreateEntitySchemas do
  use Ecto.Migration

  def change do
    # Use execute/2 for idempotent DDL so this migration is safe to run
    # against a database where Jarga.Repo already created the table.
    execute(
      """
      CREATE TABLE IF NOT EXISTS entity_schemas (
        id uuid PRIMARY KEY,
        workspace_id uuid NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
        entity_types jsonb NOT NULL DEFAULT '[]',
        edge_types jsonb NOT NULL DEFAULT '[]',
        version integer NOT NULL DEFAULT 1,
        inserted_at timestamp(0) NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
        updated_at timestamp(0) NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
      )
      """,
      "DROP TABLE IF EXISTS entity_schemas"
    )

    execute(
      """
      CREATE UNIQUE INDEX IF NOT EXISTS entity_schemas_workspace_id_index
        ON entity_schemas (workspace_id)
      """,
      "DROP INDEX IF EXISTS entity_schemas_workspace_id_index"
    )
  end
end
