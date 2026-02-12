defmodule JargaApi.Accounts.Application do
  @moduledoc """
  Application layer boundary for the API Accounts context.

  Contains cross-domain use cases that coordinate between Identity and
  Jarga domain contexts (Workspaces, Projects, Documents) for API access.

  ## Cross-Domain Use Cases

  - `UseCases.ListAccessibleWorkspaces` - List workspaces accessible via API key
  - `UseCases.GetWorkspaceWithDetails` - Get workspace with documents and projects
  - `UseCases.CreateProjectViaApi` - Create project via API key
  - `UseCases.GetProjectWithDocumentsViaApi` - Get project with documents via API
  - `UseCases.CreateDocumentViaApi` - Create document via API key
  - `UseCases.GetDocumentViaApi` - Get document via API key

  ## Dependency Rule

  The Application layer depends on:
  - Identity (for user and API key entities and policies)
  - JargaApi.Accounts.Domain (for scope interpretation)
  """

  use Boundary,
    top_level?: true,
    deps: [Identity, JargaApi.Accounts.Domain],
    exports: [
      UseCases.ListAccessibleWorkspaces,
      UseCases.GetWorkspaceWithDetails,
      UseCases.CreateProjectViaApi,
      UseCases.GetProjectWithDocumentsViaApi,
      UseCases.CreateDocumentViaApi,
      UseCases.GetDocumentViaApi
    ]
end
