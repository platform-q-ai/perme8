defmodule Jarga.Documents do
  @moduledoc """
  The Documents context.

  Handles document creation, management, and embedded notes.
  Documents are private to the user who created them, regardless of workspace membership.
  Each document has an embedded note for collaborative editing.
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Main context module and shared types (Document, DocumentComponent, Notes subdomain)
  # Internal modules (Queries, Policies) remain private
  # DocumentComponent is exported for document-note relationships
  # Notes subdomain is exported for external access to note functionality
  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Accounts,
      Jarga.Workspaces,
      Jarga.Projects,
      Jarga.Agents,
      Jarga.Repo
    ],
    exports: [
      {Domain.Entities.Document, []},
      {Domain.Entities.DocumentComponent, []},
      {Notes, []}
    ]

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository
  alias Jarga.Documents.Domain.Entities.Document
  alias Jarga.Documents.Infrastructure.Queries.DocumentQueries
  alias Jarga.Documents.Application.UseCases

  @doc """
  Gets a single document for a user.

  Only returns the document if it belongs to the user.
  Raises `Ecto.NoResultsError` if the document does not exist or belongs to another user.

  ## Options

    * `:preload_components` - If true, preloads document_components association. Defaults to false.

  ## Examples

      iex> get_document!(user, document_id)
      %Document{}

      iex> get_document!(user, document_id, preload_components: true)
      %Document{document_components: [...]}

      iex> get_document!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_document!(%User{} = user, document_id, opts \\ []) do
    schema =
      DocumentQueries.base()
      |> DocumentQueries.by_id(document_id)
      |> DocumentQueries.for_user(user)
      |> Repo.one!()

    schema =
      if Keyword.get(opts, :preload_components, false) do
        Repo.preload(schema, :document_components)
      else
        schema
      end

    Document.from_schema(schema)
  end

  @doc """
  Gets a single document by slug for a user in a workspace.

  Returns {:ok, document} or {:error, :document_not_found}

  ## Examples

      iex> get_document_by_slug(user, workspace_id, "my-document")
      {:ok, %Document{}}

      iex> get_document_by_slug(user, workspace_id, "nonexistent")
      {:error, :document_not_found}

  """
  def get_document_by_slug(%User{} = user, workspace_id, slug) do
    schema =
      DocumentQueries.base()
      |> DocumentQueries.by_slug(slug)
      |> DocumentQueries.for_workspace(workspace_id)
      |> DocumentQueries.viewable_by_user(user)
      |> DocumentQueries.with_components()
      |> Repo.one()

    case schema do
      nil -> {:error, :document_not_found}
      schema -> {:ok, Document.from_schema(schema)}
    end
  end

  @doc """
  Gets a single document by slug for a user in a workspace.

  Only returns the document if it belongs to the user.
  Raises `Ecto.NoResultsError` if the document does not exist with that slug or belongs to another user.

  ## Examples

      iex> get_document_by_slug!(user, workspace_id, "my-document")
      %Document{}

      iex> get_document_by_slug!(user, workspace_id, "nonexistent")
      ** (Ecto.NoResultsError)

  """
  def get_document_by_slug!(%User{} = user, workspace_id, slug) do
    schema =
      DocumentQueries.base()
      |> DocumentQueries.by_slug(slug)
      |> DocumentQueries.for_workspace(workspace_id)
      |> DocumentQueries.viewable_by_user(user)
      |> Repo.one!()

    Document.from_schema(schema)
  end

  @doc """
  Creates a document for a user in a workspace.

  The user must be a member of the workspace with permission to create documents.
  Members, admins, and owners can create documents. Guests cannot.
  The document is private to the user who created it.
  A default note is created and embedded in the document.

  ## Examples

      iex> create_document(user, workspace_id, %{title: "My Document"})
      {:ok, %Document{}}

      iex> create_document(user, non_member_workspace_id, %{title: "Document"})
      {:error, :unauthorized}

      iex> create_document(guest, workspace_id, %{title: "Document"})
      {:error, :forbidden}

  """
  def create_document(%User{} = user, workspace_id, attrs) do
    UseCases.CreateDocument.execute(%{
      actor: user,
      workspace_id: workspace_id,
      attrs: attrs
    })
  end

  @doc """
  Updates a document.

  Permission rules:
  - Users can edit their own documents
  - Members and admins can edit shared (public) documents
  - Admins can only edit shared documents, not private documents of others
  - Owners cannot edit documents they don't own (respects privacy)
  - Pinning follows the same rules as editing

  ## Examples

      iex> update_document(user, document_id, %{title: "New Title"})
      {:ok, %Document{}}

      iex> update_document(user, document_id, %{title: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_document(member, other_user_private_document_id, %{title: "Hacked"})
      {:error, :forbidden}

      iex> update_document(member, other_user_public_document_id, %{title: "Edit"})
      {:ok, %Document{}}

      iex> update_document(member, other_user_public_document_id, %{is_pinned: true})
      {:ok, %Document{}}

  """
  def update_document(%User{} = user, document_id, attrs, opts \\ []) do
    UseCases.UpdateDocument.execute(
      %{
        actor: user,
        document_id: document_id,
        attrs: attrs
      },
      opts
    )
  end

  @doc """
  Deletes a document.

  Permission rules:
  - Users can delete their own documents
  - Admins can delete shared (public) documents
  - Admins cannot delete private documents of others
  - Owners cannot delete documents they don't own (respects privacy)
  Deleting a document also deletes its embedded note.

  ## Examples

      iex> delete_document(user, document_id)
      {:ok, %Document{}}

      iex> delete_document(member, other_user_document_id)
      {:error, :forbidden}

      iex> delete_document(admin, other_user_public_document_id)
      {:ok, %Document{}}

  """
  def delete_document(%User{} = user, document_id) do
    UseCases.DeleteDocument.execute(%{
      actor: user,
      document_id: document_id
    })
  end

  @doc """
  Lists all documents viewable by a user in a workspace.

  Returns documents that are either:
  - Created by the user, OR
  - Public documents created by other workspace members

  ## Examples

      iex> list_documents_for_workspace(user, workspace_id)
      [%Document{}, ...]

  """
  def list_documents_for_workspace(%User{} = user, workspace_id) do
    schemas =
      DocumentQueries.base()
      |> DocumentQueries.for_workspace(workspace_id)
      |> DocumentQueries.workspace_level_only()
      |> DocumentQueries.viewable_by_user(user)
      |> DocumentQueries.ordered()
      |> Repo.all()

    Enum.map(schemas, &Document.from_schema/1)
  end

  @doc """
  Lists all documents viewable by a user in a project.

  Returns documents that are either:
  - Created by the user, OR
  - Public documents created by other workspace members

  ## Examples

      iex> list_documents_for_project(user, workspace_id, project_id)
      [%Document{}, ...]

  """
  def list_documents_for_project(%User{} = user, workspace_id, project_id) do
    schemas =
      DocumentQueries.base()
      |> DocumentQueries.for_workspace(workspace_id)
      |> DocumentQueries.for_project(project_id)
      |> DocumentQueries.viewable_by_user(user)
      |> DocumentQueries.ordered()
      |> Repo.all()

    Enum.map(schemas, &Document.from_schema/1)
  end

  @doc """
  Gets the note component from a document.

  Returns the Note associated with the first note component in the document.
  Raises if the document has no note component.

  ## Examples

      iex> get_document_note(document)
      %Note{}

  """
  def get_document_note(%Document{document_components: document_components}) do
    case Enum.find(document_components, fn dc -> dc.component_type == "note" end) do
      %{component_id: note_id} ->
        case NoteRepository.get_by_id(note_id) do
          nil -> raise "Note not found: #{note_id}"
          note -> note
        end

      nil ->
        raise "Document has no note component"
    end
  end

  @doc """
  Executes an agent query command within document context.

  Parses `@j agent_name Question` syntax, looks up agent by name,
  and streams response inline in the document.

  ## Parameters

    - `params` - Map containing:
      - `:command` - The command text (e.g., "@j my-agent What is this?")
      - `:user` - User executing the query
      - `:workspace_id` - ID of the workspace
      - `:assigns` - LiveView assigns with document context
      - `:node_id` - Node ID for streaming responses
    - `caller_pid` - PID to send streaming responses to

  ## Returns

    - `{:ok, pid}` - Agent query started successfully
    - `{:error, :invalid_command_format}` - Command parsing failed
    - `{:error, :agent_not_found}` - Agent doesn't exist in workspace
    - `{:error, :agent_disabled}` - Agent exists but is disabled

  ## Examples

      iex> execute_agent_query(%{command: "@j agent1 Hello", assigns: assigns, user: user, workspace_id: wid, node_id: "node_1"}, self())
      {:ok, #PID<...>}

  """
  def execute_agent_query(params, caller_pid) do
    UseCases.ExecuteAgentQuery.execute(params, caller_pid)
  end
end
