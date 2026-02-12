defmodule JargaApi.Accounts.Application.UseCases.CreateDocumentViaApi do
  @moduledoc """
  Use case for creating a document via API key.

  This use case handles document creation through the API, verifying that the
  API key has access to the target workspace before creating the document.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were creating the document directly via the web interface.

  ## Visibility Translation

  The API accepts a `"visibility"` field with values `"public"` or `"private"`,
  which is translated to `is_public: true/false` for the domain context.
  When no visibility is provided, it defaults to `is_public: false` (private).

  ## Project Support

  When `"project_slug"` is provided in attrs, the use case fetches the project
  first and passes its `project_id` to the document creation function.

  ## Dependency Injection

  The use case uses dependency injection for cross-context operations:
  - `get_workspace_and_member_by_slug` - Function to fetch workspace with member info
  - `create_document` - Function to create a document
  - `get_project_by_slug` - Function to fetch a project by slug (only needed when project_slug is in attrs)

  This design maintains Clean Architecture boundaries - the Accounts context
  does not depend on Documents, Projects, or Workspaces contexts. The caller
  (controller) provides the context functions.
  """

  alias JargaApi.Accounts.Domain.ApiKeyScope

  # Whitelist of allowed document attributes.
  # Only these keys are forwarded to the domain context, preventing
  # unexpected or malicious keys from reaching the changeset layer.
  @allowed_attrs ~w(title content is_public project_id)a

  @doc """
  Executes the create document via API use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `workspace_slug` - The slug of the workspace to create the document in
    - `attrs` - Document attributes:
      - `"title"` - Document title (required)
      - `"content"` - Document content (optional, passed through)
      - `"visibility"` - "public" or "private" (optional, defaults to "private")
      - `"project_slug"` - Project slug (optional, triggers project lookup)
    - `opts` - Required options for dependency injection:
      - `get_workspace_and_member_by_slug` - Function (user, slug -> {:ok, workspace, member} | {:error, reason})
      - `create_document` - Function (user, workspace_id, attrs -> {:ok, document} | {:error, reason})
      - `get_project_by_slug` - Function (user, workspace_id, slug -> {:ok, project} | {:error, :project_not_found})

  ## Returns

    - `{:ok, document}` on success
    - `{:error, :forbidden}` when API key lacks workspace access
    - `{:error, :workspace_not_found}` when workspace doesn't exist
    - `{:error, :unauthorized}` when user doesn't have access to workspace
    - `{:error, :project_not_found}` when project doesn't exist
    - `{:error, changeset}` when validation fails

  """
  @spec execute(map(), map(), String.t(), map(), keyword()) ::
          {:ok, map()}
          | {:error, :forbidden}
          | {:error, :workspace_not_found}
          | {:error, :unauthorized}
          | {:error, :project_not_found}
          | {:error, Ecto.Changeset.t()}
  def execute(user, api_key, workspace_slug, attrs, opts \\ [])

  # Handle empty or nil workspace_access - no access to any workspace
  def execute(_user, %{workspace_access: nil}, _workspace_slug, _attrs, _opts),
    do: {:error, :forbidden}

  def execute(_user, %{workspace_access: []}, _workspace_slug, _attrs, _opts),
    do: {:error, :forbidden}

  def execute(user, api_key, workspace_slug, attrs, opts) do
    with :ok <- verify_api_key_access(api_key, workspace_slug),
         {:ok, workspace, _member} <- fetch_workspace(user, workspace_slug, opts),
         {:ok, attrs} <- maybe_fetch_project(user, workspace.id, attrs, opts) do
      attrs =
        attrs
        |> translate_visibility()
        |> sanitize_attrs()

      create_document(user, workspace.id, attrs, opts)
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

  defp maybe_fetch_project(user, workspace_id, attrs, opts) do
    case Map.get(attrs, "project_slug") do
      nil ->
        {:ok, attrs}

      project_slug ->
        get_project_fn = Keyword.fetch!(opts, :get_project_by_slug)

        case get_project_fn.(user, workspace_id, project_slug) do
          {:ok, project} ->
            attrs =
              attrs
              |> Map.put("project_id", project.id)
              |> Map.delete("project_slug")

            {:ok, attrs}

          {:error, :project_not_found} ->
            {:error, :project_not_found}
        end
    end
  end

  defp translate_visibility(attrs) do
    {visibility, attrs} = Map.pop(attrs, "visibility")

    is_public =
      case visibility do
        "public" -> true
        _ -> false
      end

    Map.put(attrs, "is_public", is_public)
  end

  # Converts string-keyed attrs to atom-keyed using a whitelist approach.
  # Only keys in @allowed_attrs are included, preventing ArgumentError from
  # String.to_existing_atom/1 on unexpected keys and filtering out any
  # attributes that shouldn't reach the domain layer.
  defp sanitize_attrs(attrs) do
    Enum.reduce(@allowed_attrs, %{}, fn key, acc ->
      case fetch_attr(attrs, key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  # Fetches an attribute by its atom key, trying the string-keyed version first.
  defp fetch_attr(attrs, key) do
    str_key = Atom.to_string(key)

    case Map.fetch(attrs, str_key) do
      {:ok, _value} = result -> result
      :error -> Map.fetch(attrs, key)
    end
  end

  defp create_document(user, workspace_id, attrs, opts) do
    create_document_fn = Keyword.fetch!(opts, :create_document)
    create_document_fn.(user, workspace_id, attrs)
  end
end
