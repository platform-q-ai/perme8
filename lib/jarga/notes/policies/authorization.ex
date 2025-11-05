defmodule Jarga.Notes.Policies.Authorization do
  @moduledoc """
  Authorization policies for Notes context.
  Encapsulates business rules for note access control.
  """

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Workspaces
  alias Jarga.Notes.{Note, Queries}

  @doc """
  Verifies that a user can create a note in a workspace.
  Returns {:ok, workspace} if authorized, {:error, reason} otherwise.
  """
  def verify_workspace_access(%User{} = user, workspace_id) do
    Workspaces.get_workspace(user, workspace_id)
  end

  @doc """
  Verifies that a user can access a note (owner only).
  Returns {:ok, note} if authorized, {:error, reason} otherwise.
  """
  def verify_note_access(%User{} = user, note_id) do
    case Queries.base()
         |> Queries.by_id(note_id)
         |> Queries.for_user(user)
         |> Repo.one() do
      nil ->
        # Check if note exists at all
        if Repo.get(Note, note_id) do
          {:error, :unauthorized}
        else
          {:error, :note_not_found}
        end

      note ->
        {:ok, note}
    end
  end

  @doc """
  Verifies that a user can access a note via page permissions.

  This checks if the user can edit the page that contains the note,
  following page-level authorization (owner or workspace member for public pages).

  Returns {:ok, note} if authorized, {:error, reason} otherwise.
  """
  def verify_note_access_via_page(%User{} = user, note_id) do
    import Ecto.Query

    # Find the note and its associated page via page_components
    query =
      from(n in Note,
        join: pc in Jarga.Pages.PageComponent,
        on: pc.component_id == n.id and pc.component_type == "note",
        join: p in Jarga.Pages.Page,
        on: p.id == pc.page_id,
        left_join: wm in Jarga.Workspaces.WorkspaceMember,
        on: wm.workspace_id == p.workspace_id and wm.user_id == ^user.id,
        where: n.id == ^note_id,
        where: p.user_id == ^user.id or (p.is_public == true and not is_nil(wm.id)),
        select: n
      )

    case Repo.one(query) do
      nil ->
        # Check if note exists at all
        if Repo.get(Note, note_id) do
          {:error, :unauthorized}
        else
          {:error, :note_not_found}
        end

      note ->
        {:ok, note}
    end
  end

  @doc """
  Verifies that a project belongs to a workspace.
  Returns :ok if valid, {:error, reason} otherwise.
  """
  def verify_project_in_workspace(_workspace_id, nil), do: :ok

  def verify_project_in_workspace(workspace_id, project_id) do
    # Check if project exists and belongs to workspace
    import Ecto.Query

    query =
      from(p in Jarga.Projects.Project,
        where: p.id == ^project_id and p.workspace_id == ^workspace_id
      )

    case Repo.one(query) do
      nil -> {:error, :invalid_project}
      _project -> :ok
    end
  end
end
