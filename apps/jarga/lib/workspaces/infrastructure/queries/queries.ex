defmodule Jarga.Workspaces.Infrastructure.Queries.Queries do
  @moduledoc """
  Query objects for workspace-related database queries.

  This module provides composable, reusable query functions following the
  Query Object pattern from the infrastructure layer.
  """

  @behaviour Jarga.Workspaces.Application.Behaviours.QueriesBehaviour

  import Ecto.Query, warn: false

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Workspaces.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}

  @doc """
  Base query for workspaces.
  """
  def base do
    WorkspaceSchema
  end

  @doc """
  Filters workspaces by user membership.

  Returns a query that only includes workspaces where the given user is a member.

  ## Examples

      iex> base() |> for_user(user) |> Repo.all()
      [%Workspace{}, ...]

  """
  def for_user(query \\ base(), %{id: user_id}) do
    from(w in query,
      join: wm in WorkspaceMemberSchema,
      as: :member,
      on: wm.workspace_id == w.id,
      where: wm.user_id == ^user_id
    )
  end

  @doc """
  Preloads the current user's workspace member record.

  Uses the existing :member join from for_user/2 to efficiently preload
  the workspace_member record without an additional query.

  ## Examples

      iex> base() |> for_user(user) |> with_current_member() |> Repo.one()
      %Workspace{workspace_members: [%WorkspaceMember{}]}

  """
  def with_current_member(query) do
    from([w, member: wm] in query,
      preload: [workspace_members: wm]
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
  def for_user_by_id(%{id: _} = user, workspace_id) do
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
  def for_user_by_slug(%{id: _} = user, slug) do
    base()
    |> for_user(user)
    |> where([w], w.slug == ^slug)
  end

  @doc """
  Finds a workspace by slug for a specific user, with member preloaded.

  Returns a query that finds a workspace with the current user's
  workspace_member record preloaded (avoiding a second query).

  ## Examples

      iex> for_user_by_slug_with_member(user, "my-workspace") |> Repo.one()
      %Workspace{workspace_members: [%WorkspaceMember{}]}

  """
  def for_user_by_slug_with_member(%{id: _} = user, slug) do
    base()
    |> for_user(user)
    |> with_current_member()
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
    from(wm in WorkspaceMemberSchema,
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
    from(wm in WorkspaceMemberSchema,
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
    from(wm in WorkspaceMemberSchema,
      where: wm.workspace_id == ^workspace_id,
      where: wm.user_id == ^user.id
    )
  end

  @doc """
  Finds a pending invitation by workspace and user.

  Returns a query for a workspace member record that hasn't been accepted yet
  (joined_at is nil) and matches either the user_id or has no user_id set.

  ## Examples

      iex> find_pending_invitation(workspace_id, user_id) |> Repo.one()
      %WorkspaceMember{}

  """
  def find_pending_invitation(workspace_id, user_id) do
    from(wm in WorkspaceMemberSchema,
      where: wm.workspace_id == ^workspace_id,
      where: is_nil(wm.joined_at),
      where: wm.user_id == ^user_id or is_nil(wm.user_id)
    )
  end

  @doc """
  Finds all pending invitations for a user's email (case-insensitive).

  Returns a query for workspace member records that have no user_id set,
  haven't been joined yet, and match the given email address.

  ## Examples

      iex> find_pending_invitations_by_email(user_email) |> Repo.all()
      [%WorkspaceMember{}, ...]

  """
  @impl true
  def find_pending_invitations_by_email(email) do
    from(wm in WorkspaceMemberSchema,
      where: is_nil(wm.user_id),
      where: is_nil(wm.joined_at),
      where: fragment("LOWER(?)", wm.email) == ^String.downcase(email)
    )
  end

  @doc """
  Preloads workspace and inviter associations on a query.

  ## Examples

      iex> find_pending_invitations_by_email(user_email) |> with_workspace_and_inviter() |> Repo.all()
      [%WorkspaceMember{workspace: %Workspace{}, inviter: %User{}}, ...]

  """
  @impl true
  def with_workspace_and_inviter(query) do
    from(wm in query,
      preload: [:workspace, :inviter]
    )
  end
end
