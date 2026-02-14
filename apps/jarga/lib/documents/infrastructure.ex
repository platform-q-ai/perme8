defmodule Jarga.Documents.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Documents context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.DocumentSchema` - Ecto schema for documents table
  - `Schemas.DocumentComponentSchema` - Ecto schema for document components

  ## Repositories (Data Access)
  - `Repositories.DocumentRepository` - Document persistence operations
  - `Repositories.AuthorizationRepository` - Authorization data access

  ## Queries (Ecto Query Builders)
  - `Queries.DocumentQueries` - Document query operations

  ## Notifiers (External Communication)
  - `Notifiers.PubSubNotifier` - PubSub notifications for documents

  ## Services
  - `Services.ComponentLoader` - Polymorphic component loading

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities and policies)
  - Application layer (to implement service behaviours)
  - Shared infrastructure (Repo)

  It can use external libraries (Ecto, Phoenix.PubSub, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Documents.Domain,
      Jarga.Documents.Application,
      Jarga.Documents.Notes.Infrastructure,
      Jarga.Repo,
      # Cross-context dependencies
      Identity,
      Identity.Repo,
      Jarga.Accounts,
      Jarga.Workspaces,
      Jarga.Projects,
      Jarga.Projects.Infrastructure
    ],
    exports: [
      Schemas.DocumentSchema,
      Schemas.DocumentComponentSchema,
      Repositories.DocumentRepository,
      Repositories.AuthorizationRepository,
      Queries.DocumentQueries,
      Notifiers.PubSubNotifier,
      Services.ComponentLoader
    ]
end
