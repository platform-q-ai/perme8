defmodule Jarga.Documents.Notes.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Notes subdomain within Documents context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.NoteSchema` - Ecto schema for notes table

  ## Repositories (Data Access)
  - `Repositories.NoteRepository` - Note persistence operations
  - `Repositories.AuthorizationRepository` - Authorization data access

  ## Queries (Ecto Query Builders)
  - `Queries.Queries` - Note query operations

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities)
  - Shared infrastructure (Repo)

  It can use external libraries (Ecto, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Documents.Notes.Domain,
      Jarga.Repo,
      # Cross-context dependencies (context + domain/infrastructure layer for entity access)
      Jarga.Accounts,
      Jarga.Accounts.Domain,
      Jarga.Workspaces,
      Jarga.Workspaces.Infrastructure,
      Jarga.Projects,
      Jarga.Projects.Infrastructure
    ],
    exports: [
      Schemas.NoteSchema,
      Repositories.NoteRepository,
      Repositories.AuthorizationRepository,
      Queries.Queries
    ]
end
