defmodule EntityRelationshipManager.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Entity Relationship Manager.

  The infrastructure layer handles all external concerns:

  - **Repositories** - SchemaRepository (Ecto/Postgres), GraphRepository (Neo4j)
  - **Schemas** - Ecto schemas for database mapping
  - **Adapters** - Neo4j adapter for graph database access
  """

  use Boundary,
    deps: [
      EntityRelationshipManager,
      EntityRelationshipManager.Domain,
      Jarga.Repo
    ],
    exports: [
      {Repositories.SchemaRepository, []},
      {Repositories.GraphRepository, []},
      {Repositories.InMemoryGraphRepository, []},
      {Adapters.Neo4jAdapter, []},
      {Adapters.Neo4jDefaultAdapter, []},
      {Schemas.SchemaDefinitionSchema, []}
    ]
end
