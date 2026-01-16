defmodule Jarga.Notes do
  @moduledoc """
  The Notes context.

  Handles note creation, management, and yjs collaborative state.
  Notes are private to the user who created them, regardless of workspace membership.

  Notes are now a subdomain of Documents and exist only within documents.
  This context provides a facade for backward compatibility.
  """

  # Core context - delegates to Documents.Notes subdomain
  # Kept as a top-level boundary for backward compatibility
  use Boundary,
    top_level?: true,
    deps: [Jarga.Documents, Jarga.Accounts, Jarga.Workspaces, Jarga.Projects, Jarga.Repo],
    exports: []

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema
  alias Jarga.Documents.Notes.Infrastructure.Queries.Queries
  alias Jarga.Documents.Notes.Infrastructure.Repositories.AuthorizationRepository

  @doc """
  Gets a single note by ID.

  This is an internal function for cross-context use (e.g., loading page components).
  For user-facing operations, use `get_note!/2` which includes authorization.

  ## Examples

      iex> get_note_by_id(note_id)
      %Note{}

      iex> get_note_by_id("non-existent-id")
      nil

  """
  def get_note_by_id(note_id) do
    Repo.get(NoteSchema, note_id)
  end

  @doc """
  Gets a single note for a user.

  Only returns the note if it belongs to the user.
  Raises `Ecto.NoResultsError` if the note does not exist or belongs to another user.

  ## Examples

      iex> get_note!(user, note_id)
      %Note{}

      iex> get_note!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_note!(%User{} = user, note_id) do
    Queries.base()
    |> Queries.by_id(note_id)
    |> Queries.for_user(user)
    |> Repo.one!()
  end

  @doc """
  Creates a note for a user in a workspace.

  The user must be a member of the workspace.
  The note is private to the user who created it.

  ## Examples

      iex> create_note(user, workspace_id, %{id: uuid, note_content: %{}})
      {:ok, %Note{}}

      iex> create_note(user, non_member_workspace_id, %{id: uuid})
      {:error, :unauthorized}

  """
  def create_note(%User{} = user, workspace_id, attrs) do
    with {:ok, _workspace} <- AuthorizationRepository.verify_workspace_access(user, workspace_id),
         :ok <-
           AuthorizationRepository.verify_project_in_workspace(
             workspace_id,
             Map.get(attrs, :project_id)
           ) do
      attrs_with_user =
        Map.merge(attrs, %{
          user_id: user.id,
          workspace_id: workspace_id
        })

      %NoteSchema{}
      |> NoteSchema.changeset(attrs_with_user)
      |> Repo.insert()
    end
  end

  @doc """
  Updates a note.

  Only the owner of the note can update it.

  ## Examples

      iex> update_note(user, note_id, %{note_content: new_content})
      {:ok, %Note{}}

      iex> update_note(user, note_id, %{note_content: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_note(user, other_user_note_id, %{note_content: content})
      {:error, :unauthorized}

  """
  def update_note(%User{} = user, note_id, attrs) do
    case AuthorizationRepository.verify_note_access(user, note_id) do
      {:ok, note} ->
        note
        |> NoteSchema.changeset(attrs)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a note using page-level authorization.

  This allows workspace members to edit notes in public pages they have access to,
  following the page's authorization model rather than note ownership.

  ## Examples

      iex> update_note_via_document(user, note_id, %{note_content: content})
      {:ok, %Note{}}

      iex> update_note_via_document(user, unauthorized_note_id, %{note_content: content})
      {:error, :unauthorized}

  """
  def update_note_via_document(%User{} = user, note_id, attrs) do
    case AuthorizationRepository.verify_note_access_via_document(user, note_id) do
      {:ok, note} ->
        note
        |> NoteSchema.changeset(attrs)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a note.

  Only the owner of the note can delete it.

  ## Examples

      iex> delete_note(user, note_id)
      {:ok, %Note{}}

      iex> delete_note(user, other_user_note_id)
      {:error, :unauthorized}

  """
  def delete_note(%User{} = user, note_id) do
    case AuthorizationRepository.verify_note_access(user, note_id) do
      {:ok, note} ->
        Repo.delete(note)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all notes for a user in a workspace.

  Only returns notes created by the user, even if other users
  have notes in the same workspace.

  ## Examples

      iex> list_notes_for_workspace(user, workspace_id)
      [%Note{}, ...]

  """
  def list_notes_for_workspace(%User{} = user, workspace_id) do
    Queries.base()
    |> Queries.for_user(user)
    |> Queries.for_workspace(workspace_id)
    |> Queries.ordered()
    |> Repo.all()
  end

  @doc """
  Lists all notes for a user in a project.

  Only returns notes created by the user.

  ## Examples

      iex> list_notes_for_project(user, workspace_id, project_id)
      [%Note{}, ...]

  """
  def list_notes_for_project(%User{} = user, workspace_id, project_id) do
    Queries.base()
    |> Queries.for_user(user)
    |> Queries.for_workspace(workspace_id)
    |> Queries.for_project(project_id)
    |> Queries.ordered()
    |> Repo.all()
  end
end
