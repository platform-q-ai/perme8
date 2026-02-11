defmodule Jarga.Accounts.Application do
  @moduledoc """
  Application layer boundary for the Accounts context.

  Contains cross-domain use cases that coordinate between Identity and other Jarga contexts.

  ## Cross-Domain Use Cases

  These use cases remain in Jarga.Accounts because they cross domain boundaries
  into workspaces and projects:

  - `UseCases.ListAccessibleWorkspaces` - List workspaces accessible via API key
  - `UseCases.GetWorkspaceWithDetails` - Get workspace with documents and projects
  - `UseCases.CreateProjectViaApi` - Create project via API key
  - `UseCases.GetProjectWithDocumentsViaApi` - Get project with documents via API

  ## Dependency Rule

  The Application layer depends on:
  - Identity (for user and API key entities and policies)

  Note: Core identity operations (user registration, authentication, session management,
  API key CRUD) have been moved to the Identity app. This layer only contains use cases
  that need to coordinate between Identity and other Jarga contexts (Workspaces, Projects).
  """

  use Boundary,
    top_level?: true,
    deps: [Identity, Jarga.Accounts.Domain],
    exports: [
      UseCases.ListAccessibleWorkspaces,
      UseCases.GetWorkspaceWithDetails,
      UseCases.CreateProjectViaApi,
      UseCases.GetProjectWithDocumentsViaApi
    ]
end
