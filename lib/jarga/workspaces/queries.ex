defmodule Jarga.Workspaces.Queries do
  @moduledoc """
  Query objects for workspace-related database queries.

  This module provides composable, reusable query functions following the
  Query Object pattern from the infrastructure layer.
  """

  import Ecto.Query, warn: false

  alias Jarga.Accounts.User
  alias Jarga.Workspaces.{Workspace, WorkspaceMember}

  @doc """
  Base query for workspaces.
  """
  def base do
    Workspace
  end

  @doc """
  Filters workspaces by user membership.

  Returns a query that only includes workspaces where the given user is a member.

  ## Examples

      iex> base() |> for_user(user) |> Repo.all()
      [%Workspace{}, ...]

  """
  def for_user(query \\ base(), %User{} = user) do
    from(w in query,
      join: wm in WorkspaceMember,
      on: wm.workspace_id == w.id,
      where: wm.user_id == ^user.id
    )
  end

  @doc """
  Filters workspaces to only include non-archived ones.

  ## Examples

      iex> base() |> active() |> Repo.all()
      [%Workspace{}, ...]

  """
  def active(query \\ base()) do
    from(w in query,
      where: w.is_archived == false
    )
  end

  @doc """
  Orders workspaces by insertion time (newest first).

  ## Examples

      iex> base() |> ordered() |> Repo.all()
      [%Workspace{}, ...]

  """
  def ordered(query \\ base()) do
    from(w in query,
      order_by: [desc: w.inserted_at]
    )
  end

  @doc """
  Finds a workspace by ID for a specific user.

  Returns a query that finds a workspace only if the user is a member.

  ## Examples

      iex> for_user_by_id(user, workspace_id) |> Repo.one()
      %Workspace{}

  """
  def for_user_by_id(%User{} = user, workspace_id) do
    base()
    |> for_user(user)
    |> where([w], w.id == ^workspace_id)
  end

  @doc """
  Finds a workspace by slug for a specific user.

  Returns a query that finds a workspace only if the user is a member.

  ## Examples

      iex> for_user_by_slug(user, "my-workspace") |> Repo.one()
      %Workspace{}

  """
  def for_user_by_slug(%User{} = user, slug) do
    base()
    |> for_user(user)
    |> where([w], w.slug == ^slug)
  end

  @doc """
  Checks if a workspace exists by ID.

  ## Examples

      iex> exists?(workspace_id)
      #Ecto.Query<...>

  """
  def exists?(workspace_id) do
    from(w in base(),
      where: w.id == ^workspace_id,
      select: count(w.id)
    )
  end

  @doc """
  Finds a workspace member by workspace ID and email (case-insensitive).

  ## Examples

      iex> find_member_by_email(workspace_id, "user@example.com") |> Repo.one()
      %WorkspaceMember{}

  """
  def find_member_by_email(workspace_id, email) do
    from(wm in WorkspaceMember,
      where: wm.workspace_id == ^workspace_id,
      where: fragment("LOWER(?)", wm.email) == ^String.downcase(email),
      preload: [:user, :workspace]
    )
  end

  @doc """
  Lists all members of a workspace, ordered by joined_at.

  ## Examples

      iex> list_members(workspace_id) |> Repo.all()
      [%WorkspaceMember{}, ...]

  """
  def list_members(workspace_id) do
    from(wm in WorkspaceMember,
      where: wm.workspace_id == ^workspace_id,
      order_by: [asc: wm.joined_at, asc: wm.invited_at]
    )
  end

  @doc """
  Gets a user's workspace member record for a workspace.

  ## Examples

      iex> get_member(user, workspace_id) |> Repo.one()
      %WorkspaceMember{}

  """
  def get_member(%User{} = user, workspace_id) do
    from(wm in WorkspaceMember,
      where: wm.workspace_id == ^workspace_id,
      where: wm.user_id == ^user.id
    )
  end
end
