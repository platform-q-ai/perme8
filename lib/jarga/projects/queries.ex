defmodule Jarga.Projects.Queries do
  @moduledoc """
  Query objects for project-related database queries.

  This module provides composable, reusable query functions following the
  Query Object pattern from the infrastructure layer.
  """

  import Ecto.Query, warn: false

  alias Jarga.Accounts.User
  alias Jarga.Projects.Project
  alias Jarga.Workspaces.{Workspace, WorkspaceMember}

  @doc """
  Base query for projects.
  """
  def base do
    Project
  end

  @doc """
  Filters projects by workspace.

  Returns a query that only includes projects belonging to the specified workspace.

  ## Examples

      iex> base() |> for_workspace(workspace_id) |> Repo.all()
      [%Project{}, ...]

  """
  def for_workspace(query \\ base(), workspace_id) do
    from p in query,
      where: p.workspace_id == ^workspace_id
  end

  @doc """
  Filters projects to only include those from workspaces where the user is a member.

  ## Examples

      iex> base() |> for_user(user) |> Repo.all()
      [%Project{}, ...]

  """
  def for_user(query \\ base(), %User{} = user) do
    from p in query,
      join: w in Workspace,
      on: p.workspace_id == w.id,
      join: wm in WorkspaceMember,
      on: wm.workspace_id == w.id,
      where: wm.user_id == ^user.id
  end

  @doc """
  Filters projects to only include non-archived ones.

  ## Examples

      iex> base() |> active() |> Repo.all()
      [%Project{}, ...]

  """
  def active(query \\ base()) do
    from p in query,
      where: p.is_archived == false
  end

  @doc """
  Orders projects by insertion time (newest first).

  ## Examples

      iex> base() |> ordered() |> Repo.all()
      [%Project{}, ...]

  """
  def ordered(query \\ base()) do
    from p in query,
      order_by: [desc: p.inserted_at]
  end

  @doc """
  Finds a project by ID within a workspace for a specific user.

  Returns a query that finds a project only if:
  - The project exists
  - The project belongs to the specified workspace
  - The user is a member of the workspace

  ## Examples

      iex> for_user_by_id(user, workspace_id, project_id) |> Repo.one()
      %Project{}

  """
  def for_user_by_id(%User{} = user, workspace_id, project_id) do
    base()
    |> for_workspace(workspace_id)
    |> for_user(user)
    |> where([p], p.id == ^project_id)
  end
end
