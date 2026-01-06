defmodule Jarga.Accounts.Application.UseCases.GetWorkspaceWithDetails do
  @moduledoc """
  Use case for getting a workspace with its documents and projects.

  This use case retrieves detailed workspace information including associated
  documents and projects for API access. It verifies that the API key has
  access to the requested workspace before returning data.

  The API key acts as its owner (user), so documents and projects are fetched
  using the same authorization as the user would have - the user sees their own
  documents plus public documents from other workspace members.

  ## Dependency Injection

  The use case uses dependency injection for cross-context queries:
  - `get_workspace_by_slug` - Function to fetch workspace for a user by slug
  - `list_documents_for_workspace` - Function (user, workspace_id -> [document])
  - `list_projects_for_workspace` - Function (user, workspace_id -> [project])

  This design maintains Clean Architecture boundaries - the Accounts context
  does not depend on Documents or Projects contexts. The caller (controller)
  provides the context functions.
  """

  alias Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy

  @doc """
  Executes the get workspace with details use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `workspace_slug` - The slug of the workspace to retrieve
    - `opts` - Required options for dependency injection:
      - `get_workspace_by_slug` - Function (user, slug -> {:ok, workspace} | {:error, reason})
      - `list_documents_for_workspace` - Function (user, workspace_id -> [document])
      - `list_projects_for_workspace` - Function (user, workspace_id -> [project])

  ## Returns

    - `{:ok, workspace_data}` on success, where workspace_data includes:
      - name, slug: basic workspace info (no IDs exposed to API)
      - documents: list of documents viewable by user (own + public) with title, slug
      - projects: list of projects with name, slug
    - `{:error, :forbidden}` when API key lacks workspace access
    - `{:error, :workspace_not_found}` when workspace doesn't exist
    - `{:error, :unauthorized}` when user doesn't have access to workspace

  ## Examples

      iex> api_key = %ApiKey{workspace_access: ["product-team"]}
      iex> opts = [
      ...>   get_workspace_by_slug: &Workspaces.get_workspace_by_slug/2,
      ...>   list_documents_for_workspace: &Documents.list_documents_for_workspace/2,
      ...>   list_projects_for_workspace: &Projects.list_projects_for_workspace/2
      ...> ]
      iex> GetWorkspaceWithDetails.execute(user, api_key, "product-team", opts)
      {:ok, %{name: "Product Team", slug: "product-team", documents: [...], projects: [...]}}

      iex> api_key = %ApiKey{workspace_access: ["other-workspace"]}
      iex> GetWorkspaceWithDetails.execute(user, api_key, "product-team", opts)
      {:error, :forbidden}

  """
  @spec execute(map(), map(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :forbidden}
          | {:error, :workspace_not_found}
          | {:error, :unauthorized}
  def execute(user, api_key, workspace_slug, opts \\ [])

  # Handle empty or nil workspace_access - no access to any workspace
  def execute(_user, %{workspace_access: nil}, _workspace_slug, _opts), do: {:error, :forbidden}
  def execute(_user, %{workspace_access: []}, _workspace_slug, _opts), do: {:error, :forbidden}

  def execute(user, api_key, workspace_slug, opts) do
    # First check if API key has access to this workspace
    if WorkspaceAccessPolicy.has_workspace_access?(api_key, workspace_slug) do
      # Get the functions from opts - these MUST be provided by caller
      get_workspace_fn = Keyword.fetch!(opts, :get_workspace_by_slug)
      list_documents_fn = Keyword.fetch!(opts, :list_documents_for_workspace)
      list_projects_fn = Keyword.fetch!(opts, :list_projects_for_workspace)

      # Fetch workspace using user's authorization (by slug)
      case get_workspace_fn.(user, workspace_slug) do
        {:ok, workspace} ->
          # Fetch documents and projects using workspace ID (efficient, no extra joins)
          documents = list_documents_fn.(user, workspace.id)
          projects = list_projects_fn.(user, workspace.id)

          # Build the result map (only slugs, no IDs for external API)
          result = %{
            name: workspace.name,
            slug: workspace.slug,
            documents: format_documents(documents),
            projects: format_projects(projects)
          }

          {:ok, result}

        {:error, :workspace_not_found} ->
          {:error, :workspace_not_found}

        {:error, :unauthorized} ->
          {:error, :unauthorized}
      end
    else
      {:error, :forbidden}
    end
  end

  defp format_documents(documents) do
    Enum.map(documents, fn doc ->
      %{
        title: get_field(doc, :title),
        slug: get_field(doc, :slug)
      }
    end)
  end

  defp format_projects(projects) do
    Enum.map(projects, fn project ->
      %{
        name: get_field(project, :name),
        slug: get_field(project, :slug)
      }
    end)
  end

  # Helper to get field from struct or map
  defp get_field(data, key) when is_struct(data), do: Map.get(data, key)
  defp get_field(data, key) when is_map(data), do: data[key] || Map.get(data, key)
end
