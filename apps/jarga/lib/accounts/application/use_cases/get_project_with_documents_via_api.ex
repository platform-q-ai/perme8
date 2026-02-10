defmodule Jarga.Accounts.Application.UseCases.GetProjectWithDocumentsViaApi do
  @moduledoc """
  Use case for getting a project with its documents via API key.

  This use case retrieves project information including associated documents
  for API access. It verifies that the API key has access to the workspace
  containing the project before returning data.

  The API key acts as its owner (user), so documents are fetched using the
  same authorization as the user would have.

  ## Dependency Injection

  The use case uses dependency injection for cross-context queries:
  - `get_workspace_and_member_by_slug` - Function to fetch workspace with member info
  - `get_project_by_slug` - Function to fetch project by slug
  - `list_documents_for_project` - Function to list documents for a project

  This design maintains Clean Architecture boundaries - the Accounts context
  does not depend on Projects or Documents contexts. The caller (controller)
  provides the context functions.
  """

  alias Jarga.Accounts.Domain.ApiKeyScope

  @doc """
  Executes the get project with documents via API use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `workspace_slug` - The slug of the workspace
    - `project_slug` - The slug of the project to retrieve
    - `opts` - Required options for dependency injection:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `get_project_by_slug` - Function (user, workspace_id, project_slug -> {:ok, project} | {:error, reason})
      - `list_documents_for_project` - Function (user, workspace_id, project_id -> [document])

  ## Returns

    - `{:ok, %{project: project, documents: documents}}` on success
    - `{:error, :forbidden}` when API key lacks workspace access
    - `{:error, :workspace_not_found}` when workspace doesn't exist
    - `{:error, :project_not_found}` when project doesn't exist
    - `{:error, :unauthorized}` when user doesn't have access to workspace

  """
  @spec execute(map(), map(), String.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :forbidden}
          | {:error, :workspace_not_found}
          | {:error, :project_not_found}
          | {:error, :unauthorized}
  def execute(user, api_key, workspace_slug, project_slug, opts \\ [])

  # Handle empty or nil workspace_access - no access to any workspace
  def execute(_user, %{workspace_access: nil}, _workspace_slug, _project_slug, _opts),
    do: {:error, :forbidden}

  def execute(_user, %{workspace_access: []}, _workspace_slug, _project_slug, _opts),
    do: {:error, :forbidden}

  def execute(user, api_key, workspace_slug, project_slug, opts) do
    # First check if API key has access to this workspace
    with :ok <- verify_api_key_access(api_key, workspace_slug),
         {:ok, workspace, _member} <- fetch_workspace(user, workspace_slug, opts),
         {:ok, project} <- fetch_project(user, workspace.id, project_slug, opts) do
      documents = fetch_documents(user, workspace.id, project.id, opts)
      {:ok, %{project: project, documents: documents}}
    end
  end

  defp verify_api_key_access(api_key, workspace_slug) do
    if ApiKeyScope.includes?(api_key, workspace_slug) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp fetch_workspace(user, workspace_slug, opts) do
    get_workspace_fn = Keyword.fetch!(opts, :get_workspace_and_member_by_slug)
    get_workspace_fn.(user, workspace_slug)
  end

  defp fetch_project(user, workspace_id, project_slug, opts) do
    get_project_fn = Keyword.fetch!(opts, :get_project_by_slug)
    get_project_fn.(user, workspace_id, project_slug)
  end

  defp fetch_documents(user, workspace_id, project_id, opts) do
    list_documents_fn = Keyword.fetch!(opts, :list_documents_for_project)
    list_documents_fn.(user, workspace_id, project_id)
  end
end
