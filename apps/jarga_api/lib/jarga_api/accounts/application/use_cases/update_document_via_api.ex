defmodule JargaApi.Accounts.Application.UseCases.UpdateDocumentViaApi do
  @moduledoc """
  Use case for updating a document via API key.

  This use case handles document updates through the API, verifying that the
  API key has access to the target workspace before updating the document.

  The API key acts as its owner (user), so the same authorization rules apply
  as if the user were updating the document directly via the web interface.

  ## Visibility Translation

  The API accepts a `"visibility"` field with values `"public"` or `"private"`,
  which is translated to `is_public: true/false` for the domain context.
  Unlike create (which defaults to private), update only sets `is_public` when
  `"visibility"` is explicitly provided. Omitting it means "don't change it."

  ## Content Updates with Optimistic Concurrency

  When `"content"` is provided, a `"content_hash"` must also be provided.
  The hash is compared against the current content's hash to detect stale writes.
  If the hashes don't match, a conflict error is returned with the current content
  and its hash so the client can re-base.

  ## Error Tuples

  Most errors follow the standard `{:error, reason}` pattern. The content conflict
  error uses a 3-element tuple `{:error, :content_conflict, conflict_data}` to
  include the current server content for client re-basing. The controller handles
  this shape explicitly.

  ## No Transaction Boundary

  The document metadata update and note content update are separate operations.
  This is acceptable because they are independent resources, and partial failure
  can be retried by the client. If stronger guarantees are needed later, these
  can be wrapped in an `Ecto.Multi`.

  ## Dependency Injection

  The use case uses dependency injection for cross-context operations:
  - `get_workspace_and_member_by_slug` - Function to fetch workspace with member info
  - `get_document_by_slug` - Function to fetch document by slug
  - `get_document_note` - Function to get the document's note content
  - `update_document` - Function to update document metadata
  - `update_document_note` - Function to update note content
  """

  alias JargaApi.Accounts.Domain.ApiKeyScope
  alias Jarga.Documents.Notes.Domain.ContentHash

  # Whitelist of allowed document metadata attributes.
  @allowed_document_attrs ~w(title is_public)a

  @doc """
  Executes the update document via API use case.

  ## Parameters

    - `user` - The user who owns the API key
    - `api_key` - The verified API key domain entity
    - `workspace_slug` - The slug of the workspace containing the document
    - `document_slug` - The slug of the document to update
    - `attrs` - Update attributes:
      - `"title"` - New document title (optional)
      - `"content"` - New note content (optional, requires `content_hash`)
      - `"content_hash"` - Hash of content the client based changes on (required with `content`)
      - `"visibility"` - "public" or "private" (optional)
    - `opts` - Required options for dependency injection

  ## Returns

    - `{:ok, result_map}` on success with updated document data
    - `{:error, :forbidden}` when API key lacks workspace access
    - `{:error, :content_hash_required}` when content provided without hash
    - `{:error, :content_conflict, conflict_data}` when hash mismatch (3-element error tuple)
    - `{:error, :workspace_not_found | :document_not_found | :unauthorized}`
    - `{:error, changeset}` when validation fails
  """
  @spec execute(map(), map(), String.t(), String.t(), map(), keyword()) ::
          {:ok, map()}
          | {:error, :forbidden}
          | {:error, :content_hash_required}
          | {:error, :content_conflict, map()}
          | {:error, :workspace_not_found}
          | {:error, :document_not_found}
          | {:error, :unauthorized}
          | {:error, Ecto.Changeset.t()}
  def execute(user, api_key, workspace_slug, document_slug, attrs, opts \\ [])

  # Handle empty or nil workspace_access
  def execute(_user, %{workspace_access: nil}, _ws, _ds, _attrs, _opts),
    do: {:error, :forbidden}

  def execute(_user, %{workspace_access: []}, _ws, _ds, _attrs, _opts),
    do: {:error, :forbidden}

  def execute(user, api_key, workspace_slug, document_slug, attrs, opts) do
    with :ok <- verify_api_key_access(api_key, workspace_slug),
         {:ok, workspace, _member} <- fetch_workspace(user, workspace_slug, opts),
         {:ok, document} <- fetch_document(user, workspace.id, document_slug, opts),
         {:ok, content_update, note} <- validate_content_hash(document, attrs, opts),
         {:ok, updated_doc} <- maybe_update_document_metadata(user, document, attrs, opts),
         {:ok, updated_note} <- maybe_update_note_content(document, content_update, note, opts) do
      build_success_result(updated_doc, updated_note, workspace_slug, user, opts)
    end
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

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

  # Validates content_hash when content is being updated.
  # Returns {:ok, nil, note} if no content update (note fetched for response building),
  # {:ok, content, note} if hash matches, or an error tuple if hash is missing/mismatched.
  defp validate_content_hash(document, attrs, opts) when not is_map_key(attrs, "content") do
    note = fetch_note(document, opts)
    {:ok, nil, note}
  end

  defp validate_content_hash(_document, %{"content_hash" => nil}, _opts) do
    {:error, :content_hash_required}
  end

  defp validate_content_hash(_document, attrs, _opts)
       when not is_map_key(attrs, "content_hash") do
    {:error, :content_hash_required}
  end

  defp validate_content_hash(document, attrs, opts) do
    note = fetch_note(document, opts)
    current_hash = ContentHash.compute(note.note_content)
    provided_hash = Map.get(attrs, "content_hash")

    if provided_hash == current_hash do
      {:ok, Map.get(attrs, "content"), note}
    else
      {:error, :content_conflict, %{content: note.note_content, content_hash: current_hash}}
    end
  end

  defp maybe_update_document_metadata(user, document, attrs, opts) do
    document_attrs =
      attrs
      |> maybe_translate_visibility()
      |> sanitize_document_attrs()

    if map_size(document_attrs) > 0 do
      update_document_fn = Keyword.fetch!(opts, :update_document)
      update_document_fn.(user, document.id, document_attrs)
    else
      {:ok, document}
    end
  end

  # When no content update is needed, return the existing note as-is.
  defp maybe_update_note_content(_document, nil, note, _opts), do: {:ok, note}

  defp maybe_update_note_content(document, content, _note, opts) do
    update_note_fn = Keyword.fetch!(opts, :update_document_note)

    case update_note_fn.(document, %{note_content: content}) do
      {:ok, updated_note} -> {:ok, updated_note}
      {:error, _} = error -> error
    end
  end

  # Only translate visibility when explicitly provided in attrs.
  # Omitting "visibility" means "don't change it" (unlike create, which defaults to private).
  defp maybe_translate_visibility(attrs) do
    case Map.get(attrs, "visibility") do
      "public" ->
        attrs
        |> Map.delete("visibility")
        |> Map.put("is_public", true)

      "private" ->
        attrs
        |> Map.delete("visibility")
        |> Map.put("is_public", false)

      _ ->
        Map.delete(attrs, "visibility")
    end
  end

  # Converts string-keyed attrs to atom-keyed using a whitelist approach.
  defp sanitize_document_attrs(attrs) do
    Enum.reduce(@allowed_document_attrs, %{}, fn key, acc ->
      str_key = Atom.to_string(key)

      case Map.fetch(attrs, str_key) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> maybe_put(Map.fetch(attrs, key), acc, key)
      end
    end)
  end

  defp maybe_put({:ok, value}, acc, key), do: Map.put(acc, key, value)
  defp maybe_put(:error, acc, _key), do: acc

  # Builds the success response from the actual persisted results.
  # Uses the updated document (from domain update) and note (from note update or validation)
  # rather than deriving values from raw attrs, ensuring the response reflects what's persisted.
  defp build_success_result(updated_doc, note, workspace_slug, user, opts) do
    content = note.note_content
    content_hash = ContentHash.compute(content)

    visibility = if(updated_doc.is_public, do: "public", else: "private")
    project_slug = maybe_fetch_project_slug(user, updated_doc, opts)
    owner_email = resolve_owner_email(user, updated_doc, opts)

    {:ok,
     %{
       title: updated_doc.title,
       slug: updated_doc.slug,
       content: content,
       content_hash: content_hash,
       visibility: visibility,
       owner: owner_email,
       workspace_slug: workspace_slug,
       project_slug: project_slug
     }}
  end

  defp maybe_fetch_project_slug(_user, %{project_id: nil}, _opts), do: nil

  defp maybe_fetch_project_slug(user, document, opts) do
    case Keyword.get(opts, :get_project) do
      nil ->
        nil

      get_project_fn ->
        case get_project_fn.(user, document.workspace_id, document.project_id) do
          {:ok, project} -> project.slug
          {:error, _reason} -> nil
        end
    end
  end

  defp resolve_owner_email(user, document, opts) do
    if document.created_by == user.id do
      user.email
    else
      case Keyword.get(opts, :get_user) do
        nil ->
          document.created_by

        get_user_fn ->
          case get_user_fn.(document.created_by) do
            nil -> document.created_by
            owner -> owner.email
          end
      end
    end
  end
end
