defmodule Jarga.Accounts do
  @moduledoc """
  Facade for account management operations.

  This module delegates core identity operations to the `Identity` app while
  providing workspace-related API operations that cross domain boundaries.

  ## Core Identity Operations (delegated to Identity)

  - User authentication and registration
  - Session management
  - Password and email updates
  - API key management

  ## Workspace API Operations (implemented here)

  These use cases remain in Jarga.Accounts because they cross domain boundaries
  into workspaces and projects:

  - `list_accessible_workspaces/3` - List workspaces accessible via API key
  - `get_workspace_with_details/4` - Get workspace with documents and projects
  - `create_project_via_api/5` - Create project via API key
  - `get_project_with_documents_via_api/5` - Get project with documents via API key

  ## Migration Note

  This facade delegates to Identity for all core account operations.
  Direct usage of `Identity` module is preferred for new code.
  """

  # Boundary configuration - depends on Identity for core operations
  # and Jarga.Accounts.Application for workspace API use cases
  use Boundary,
    top_level?: true,
    deps: [
      Identity,
      Jarga.Repo,
      # Workspace API use cases that remain in Jarga
      Jarga.Accounts.Application
    ],
    exports: [
      # Re-export Identity types for backward compatibility
      {Domain.Entities.User, []},
      {Domain.Entities.ApiKey, []},
      {Domain.Scope, []},
      {Domain.Services.TokenBuilder, []},
      {Domain.Policies.WorkspaceAccessPolicy, []},
      {Application.Services.PasswordService, []},
      {Application.Services.ApiKeyTokenService, []},
      {Infrastructure.Schemas.UserSchema, []},
      {Infrastructure.Schemas.UserTokenSchema, []},
      {Infrastructure.Schemas.ApiKeySchema, []}
    ]

  alias Jarga.Accounts.Application.UseCases

  # =============================================================================
  # DELEGATED TO IDENTITY - Core account operations
  # =============================================================================

  ## Database getters

  defdelegate get_user_by_email(email), to: Identity
  defdelegate get_user_by_email_case_insensitive(email), to: Identity
  defdelegate get_user_by_email_and_password(email, password), to: Identity
  defdelegate get_user(id), to: Identity
  defdelegate get_user!(id), to: Identity

  ## User registration

  defdelegate register_user(attrs), to: Identity

  ## Settings

  def sudo_mode?(user, opts \\ []), do: Identity.sudo_mode?(user, opts)

  def change_user_registration(user, attrs \\ %{}, opts \\ []),
    do: Identity.change_user_registration(user, attrs, opts)

  def change_user_email(user, attrs \\ %{}, opts \\ []),
    do: Identity.change_user_email(user, attrs, opts)

  defdelegate update_user_email(user, token), to: Identity

  def change_user_password(user, attrs \\ %{}, opts \\ []),
    do: Identity.change_user_password(user, attrs, opts)

  defdelegate update_user_password(user, attrs), to: Identity

  ## Session

  defdelegate generate_user_session_token(user), to: Identity
  defdelegate get_user_by_session_token(token), to: Identity
  defdelegate get_user_by_magic_link_token(token), to: Identity
  defdelegate login_user_by_magic_link(token), to: Identity
  defdelegate deliver_user_update_email_instructions(user, current_email, url_fun), to: Identity
  defdelegate deliver_login_instructions(user, url_fun), to: Identity
  defdelegate delete_user_session_token(token), to: Identity
  defdelegate get_user_token_by_user_id(user_id), to: Identity

  ## User preferences

  defdelegate get_selected_agent_id(user_id, workspace_id), to: Identity
  defdelegate set_selected_agent_id(user_id, workspace_id, agent_id), to: Identity

  ## API Keys

  defdelegate create_api_key(user_id, attrs), to: Identity
  def list_api_keys(user_id, opts \\ []), do: Identity.list_api_keys(user_id, opts)
  defdelegate update_api_key(user_id, api_key_id, attrs), to: Identity
  defdelegate revoke_api_key(user_id, api_key_id), to: Identity
  defdelegate verify_api_key(plain_token), to: Identity

  # =============================================================================
  # WORKSPACE API OPERATIONS - Cross-domain operations that remain in Jarga
  # =============================================================================

  @doc """
  Lists workspaces accessible via an API key.

  Returns workspaces that the user has access to AND are listed in the
  API key's workspace_access list.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `opts` - Required options:
      - `list_workspaces_for_user` - Function to list user's workspaces

  ## Returns

    `{:ok, workspaces}` - List of accessible workspaces with basic info

  """
  def list_accessible_workspaces(user, api_key, opts) do
    UseCases.ListAccessibleWorkspaces.execute(user, api_key, opts)
  end

  @doc """
  Gets a workspace with documents and projects via API key.

  Retrieves workspace details including documents and projects. The API key
  acts as its owner, so documents and projects are filtered by user access.
  All queries use workspace slug, not ID.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `workspace_slug` - The slug of the workspace to retrieve
    - `opts` - Required options:
      - `get_workspace_by_slug` - Function (user, slug -> {:ok, workspace} | {:error, reason})
      - `list_documents_by_slug` - Function (user, workspace_slug -> [document])
      - `list_projects_by_slug` - Function (user, workspace_slug -> [project])

  ## Returns

    - `{:ok, workspace_data}` - Workspace with documents and projects
    - `{:error, :forbidden}` - API key lacks workspace access
    - `{:error, :workspace_not_found}` - Workspace doesn't exist
    - `{:error, :unauthorized}` - User doesn't have access to workspace

  """
  def get_workspace_with_details(user, api_key, workspace_slug, opts) do
    UseCases.GetWorkspaceWithDetails.execute(user, api_key, workspace_slug, opts)
  end

  @doc """
  Creates a project in a workspace via API key.

  The API key must have access to the workspace and the user must have
  permission to create projects in that workspace.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `workspace_slug` - The slug of the workspace
    - `attrs` - Project attributes (name, description, etc.)
    - `opts` - Required options:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `create_project` - Function (user, workspace_id, attrs -> {:ok, project} | {:error, reason})

  ## Returns

    - `{:ok, project}` - Project created successfully
    - `{:error, :forbidden}` - API key lacks workspace access or user lacks permission
    - `{:error, :workspace_not_found}` - Workspace doesn't exist
    - `{:error, changeset}` - Validation error

  """
  def create_project_via_api(user, api_key, workspace_slug, attrs, opts) do
    UseCases.CreateProjectViaApi.execute(user, api_key, workspace_slug, attrs, opts)
  end

  @doc """
  Gets a project with its documents via API key.

  Retrieves project details including associated documents. The API key
  acts as its owner, so documents are filtered by user access.

  ## Parameters

    - `user` - The user entity (API key owner)
    - `api_key` - The verified API key entity
    - `workspace_slug` - The slug of the workspace
    - `project_slug` - The slug of the project to retrieve
    - `opts` - Required options:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `get_project_by_slug` - Function (user, workspace_id, project_slug -> {:ok, project} | {:error, reason})
      - `list_documents_for_project` - Function (user, workspace_id, project_id -> [document])

  ## Returns

    - `{:ok, %{project: project, documents: documents}}` - Project with documents
    - `{:error, :forbidden}` - API key lacks workspace access
    - `{:error, :workspace_not_found}` - Workspace doesn't exist
    - `{:error, :project_not_found}` - Project doesn't exist
    - `{:error, :unauthorized}` - User doesn't have access to workspace

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
