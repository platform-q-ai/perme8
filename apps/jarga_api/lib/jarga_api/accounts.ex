defmodule JargaApi.Accounts do
  @moduledoc """
  Facade for API-specific account operations.

  This module provides the API-specific use cases that cross domain boundaries
  into workspaces, projects, and documents.

  ## API Operations

  - `list_accessible_workspaces/3` - List workspaces accessible via API key
  - `get_workspace_with_details/4` - Get workspace with documents and projects
  - `create_project_via_api/5` - Create project via API key
  - `get_project_with_documents_via_api/5` - Get project with documents via API key
  - `create_document_via_api/5` - Create document via API key
  - `get_document_via_api/5` - Get document via API key
  """

  use Boundary,
    top_level?: true,
    deps: [
      JargaApi.Accounts.Application
    ],
    exports: []

  alias JargaApi.Accounts.Application.UseCases

  # =============================================================================
  # API OPERATIONS - Cross-domain use cases
  # =============================================================================

  @doc """
  Lists workspaces accessible via an API key.

  Returns workspaces that the user has access to AND are listed in the
  API key's workspace_access list.
  """
  def list_accessible_workspaces(user, api_key, opts) do
    UseCases.ListAccessibleWorkspaces.execute(user, api_key, opts)
  end

  @doc """
  Gets a workspace with documents and projects via API key.

  Retrieves workspace details including documents and projects. The API key
  acts as its owner, so documents and projects are filtered by user access.
  """
  def get_workspace_with_details(user, api_key, workspace_slug, opts) do
    UseCases.GetWorkspaceWithDetails.execute(user, api_key, workspace_slug, opts)
  end

  @doc """
  Creates a project in a workspace via API key.

  The API key must have access to the workspace and the user must have
  permission to create projects in that workspace.
  """
  def create_project_via_api(user, api_key, workspace_slug, attrs, opts) do
    UseCases.CreateProjectViaApi.execute(user, api_key, workspace_slug, attrs, opts)
  end

  @doc """
  Gets a project with its documents via API key.

  Retrieves project details including associated documents. The API key
  acts as its owner, so documents are filtered by user access.
  """
  def get_project_with_documents_via_api(user, api_key, workspace_slug, project_slug, opts) do
    UseCases.GetProjectWithDocumentsViaApi.execute(
      user,
      api_key,
      workspace_slug,
      project_slug,
      opts
    )
  end

  @doc """
  Creates a document in a workspace via API key.

  The API key must have access to the workspace and the user must have
  permission to create documents in that workspace. Optionally creates
  the document inside a project if project_slug is provided in attrs.
  """
  def create_document_via_api(user, api_key, workspace_slug, attrs, opts) do
    UseCases.CreateDocumentViaApi.execute(user, api_key, workspace_slug, attrs, opts)
  end

  @doc """
  Gets a document via API key.

  Retrieves document details including note content. The API key
  acts as its owner, so document visibility rules apply.
  """
  def get_document_via_api(user, api_key, workspace_slug, document_slug, opts) do
    UseCases.GetDocumentViaApi.execute(user, api_key, workspace_slug, document_slug, opts)
  end
end
