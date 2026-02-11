defmodule Jarga.Projects.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Projects context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.ProjectSchema` - Ecto schema for projects table

  ## Repositories (Data Access)
  - `Repositories.ProjectRepository` - Project persistence operations
  - `Repositories.AuthorizationRepository` - Authorization data access

  ## Queries (Ecto Query Builders)
  - `Queries.Queries` - Project query operations

  ## Notifiers (External Communication)
  - `Notifiers.EmailAndPubSubNotifier` - Email and PubSub notifications

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
      Jarga.Projects.Domain,
      Jarga.Projects.Application,
      Jarga.Repo,
      # Cross-context dependencies
      Identity,
      Jarga.Accounts,
      Jarga.Workspaces,
      Jarga.Workspaces.Infrastructure
    ],
    exports: [
      Schemas.ProjectSchema,
      Repositories.ProjectRepository,
      Repositories.AuthorizationRepository,
      Queries.Queries,
      Notifiers.EmailAndPubSubNotifier
    ]
end
