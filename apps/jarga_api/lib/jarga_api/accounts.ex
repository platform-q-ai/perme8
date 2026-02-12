defmodule JargaApi.Accounts do
  @moduledoc """
  Facade for API-specific account operations.

  This module provides the API-specific use cases that cross domain boundaries
  into workspaces, projects, and documents. It also delegates API key verification
  and user lookup to the `Identity` app.

  ## API Operations

  - `list_accessible_workspaces/3` - List workspaces accessible via API key
  - `get_workspace_with_details/4` - Get workspace with documents and projects
  - `create_project_via_api/5` - Create project via API key
  - `get_project_with_documents_via_api/5` - Get project with documents via API key

  ## Identity Delegations

  - `verify_api_key/1` - Verify an API key token
  - `get_user/1` - Get a user by ID
  """

  use Boundary,
    top_level?: true,
    deps: [
      Identity,
      JargaApi.Accounts.Application
    ],
    exports: []

  alias JargaApi.Accounts.Application.UseCases

  # =============================================================================
  # DELEGATED TO IDENTITY
  # =============================================================================

  defdelegate verify_api_key(plain_token), to: Identity
  defdelegate get_user(id), to: Identity

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
end
