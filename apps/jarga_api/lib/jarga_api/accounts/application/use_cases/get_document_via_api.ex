defmodule JargaApi.Accounts.Application.UseCases.GetDocumentViaApi do
  @moduledoc """
  Use case for retrieving a document via API key.

  This use case handles document retrieval through the API, verifying that the
  API key has access to the target workspace before fetching the document and
  its content.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were accessing the document directly via the web interface.

  ## Response Format

  Returns a result map with:
  - `title` - Document title
  - `slug` - Document slug
  - `content` - Document note content
  - `visibility` - "public" or "private"
  - `owner` - Owner email (from `created_by`)
  - `workspace_slug` - Workspace slug (passed through)
  - `project_slug` - Project slug (nil if document has no project)

  ## Dependency Injection

  The use case uses dependency injection for cross-context queries:
  - `get_workspace_and_member_by_slug` - Function to fetch workspace with member info
  - `get_document_by_slug` - Function to fetch document by slug
  - `get_document_note` - Function to get the document's note content
  - `get_project` - Function to fetch a project by ID (only called when document has a project)

  This design maintains Clean Architecture boundaries - the Accounts context
  does not depend on Documents, Projects, or Workspaces contexts. The caller
  (controller) provides the context functions.
  """

  alias JargaApi.Accounts.Domain.ApiKeyScope

  @doc """
  Executes the get document via API use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `workspace_slug` - The slug of the workspace containing the document
    - `document_slug` - The slug of the document to retrieve
    - `opts` - Required options for dependency injection:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `get_document_by_slug` - Function (user, workspace_id, slug -> {:ok, document} | {:error, :document_not_found})
      - `get_document_note` - Function (document -> note_schema)
      - `get_project` - Function (user, workspace_id, project_id -> {:ok, project} | {:error, :project_not_found})

  ## Returns

    - `{:ok, result_map}` on success with document data
    - `{:error, :forbidden}` when API key lacks workspace access
    - `{:error, :workspace_not_found}` when workspace doesn't exist
    - `{:error, :document_not_found}` when document doesn't exist or user can't access it
    - `{:error, :unauthorized}` when user doesn't have access to workspace

  """
  @spec execute(map(), map(), String.t(), String.t(), keyword()) ::
          {:ok, map()}
          | {:error, :forbidden}
          | {:error, :workspace_not_found}
          | {:error, :document_not_found}
          | {:error, :unauthorized}
  def execute(user, api_key, workspace_slug, document_slug, opts \\ [])

  # Handle empty or nil workspace_access - no access to any workspace
  def execute(_user, %{workspace_access: nil}, _workspace_slug, _document_slug, _opts),
    do: {:error, :forbidden}

  def execute(_user, %{workspace_access: []}, _workspace_slug, _document_slug, _opts),
    do: {:error, :forbidden}

  def execute(user, api_key, workspace_slug, document_slug, opts) do
    with :ok <- verify_api_key_access(api_key, workspace_slug),
         {:ok, workspace, _member} <- fetch_workspace(user, workspace_slug, opts),
         {:ok, document} <- fetch_document(user, workspace.id, document_slug, opts) do
      note = fetch_note(document, opts)
      project_slug = maybe_fetch_project_slug(user, workspace.id, document, opts)
      owner_email = resolve_owner_email(user, document, opts)

      {:ok, build_result(document, note, workspace_slug, project_slug, owner_email)}
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

  defp fetch_document(user, workspace_id, document_slug, opts) do
    get_document_fn = Keyword.fetch!(opts, :get_document_by_slug)
    get_document_fn.(user, workspace_id, document_slug)
  end

  defp fetch_note(document, opts) do
    get_note_fn = Keyword.fetch!(opts, :get_document_note)
    get_note_fn.(document)
  end

  defp maybe_fetch_project_slug(_user, _workspace_id, %{project_id: nil}, _opts), do: nil

  defp maybe_fetch_project_slug(user, workspace_id, document, opts) do
    get_project_fn = Keyword.fetch!(opts, :get_project)

    case get_project_fn.(user, workspace_id, document.project_id) do
      {:ok, project} -> project.slug
      {:error, _reason} -> nil
    end
  end

  defp resolve_owner_email(user, document, opts) do
    if document.created_by == user.id do
      user.email
    else
      case Keyword.get(opts, :get_user) do
        nil ->
          # Fallback to user ID if no get_user function provided
          document.created_by

        get_user_fn ->
          case get_user_fn.(document.created_by) do
            nil -> document.created_by
            owner -> owner.email
          end
      end
    end
  end

  defp build_result(document, note, workspace_slug, project_slug, owner_email) do
    %{
      title: document.title,
      slug: document.slug,
      content: note.note_content,
      visibility: if(document.is_public, do: "public", else: "private"),
      owner: owner_email,
      workspace_slug: workspace_slug,
      project_slug: project_slug
    }
  end
end
