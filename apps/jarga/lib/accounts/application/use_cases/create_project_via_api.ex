defmodule Jarga.Accounts.Application.UseCases.CreateProjectViaApi do
  @moduledoc """
  Use case for creating a project via API key.

  This use case handles project creation through the API, verifying that the
  API key has access to the target workspace before creating the project.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were creating the project directly via the web interface.

  ## Dependency Injection

  The use case uses dependency injection for cross-context operations:
  - `get_workspace_and_member_by_slug` - Function to fetch workspace with member info
  - `create_project` - Function to create a project

  This design maintains Clean Architecture boundaries - the Accounts context
  does not depend on Projects or Workspaces contexts. The caller (controller)
  provides the context functions.
  """

  alias Jarga.Accounts.Domain.ApiKeyScope

  @doc """
  Executes the create project via API use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `workspace_slug` - The slug of the workspace to create the project in
    - `attrs` - Project attributes (name, description, etc.)
    - `opts` - Required options for dependency injection:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `create_project` - Function (user, workspace_id, attrs -> {:ok, project} | {:error, reason})

  ## Returns

    - `{:ok, project}` on success
    - `{:error, :forbidden}` when API key lacks workspace access
    - `{:error, :workspace_not_found}` when workspace doesn't exist
    - `{:error, :unauthorized}` when user doesn't have access to workspace
    - `{:error, changeset}` when validation fails

  """
  @spec execute(map(), map(), String.t(), map(), keyword()) ::
          {:ok, map()}
          | {:error, :forbidden}
          | {:error, :workspace_not_found}
          | {:error, :unauthorized}
          | {:error, Ecto.Changeset.t()}
  def execute(user, api_key, workspace_slug, attrs, opts \\ [])

  # Handle empty or nil workspace_access - no access to any workspace
  def execute(_user, %{workspace_access: nil}, _workspace_slug, _attrs, _opts),
    do: {:error, :forbidden}

  def execute(_user, %{workspace_access: []}, _workspace_slug, _attrs, _opts),
    do: {:error, :forbidden}

  def execute(user, api_key, workspace_slug, attrs, opts) do
    # First check if workspace is within the API key's scope
    if ApiKeyScope.includes?(api_key, workspace_slug) do
      get_workspace_fn = Keyword.fetch!(opts, :get_workspace_and_member_by_slug)
      create_project_fn = Keyword.fetch!(opts, :create_project)

      # Fetch workspace using user's authorization
      case get_workspace_fn.(user, workspace_slug) do
        {:ok, workspace, _member} ->
          # Create project - the Projects context handles permission checking
          create_project_fn.(user, workspace.id, attrs)

        {:error, :workspace_not_found} ->
          {:error, :workspace_not_found}

        {:error, :unauthorized} ->
          {:error, :unauthorized}
      end
    else
      {:error, :forbidden}
    end
  end
end
