defmodule Jarga.Workspaces.Infrastructure.MembershipRepository do
  @moduledoc """
  Repository for workspace membership data access.

  This module is part of the infrastructure layer and handles all
  database queries related to workspace membership verification.

  Following Infrastructure Layer principles:
  - Encapsulates data access logic
  - Uses Ecto and Repo for database operations
  - Returns domain entities (WorkspaceMember, Workspace)
  - No business rules - just data retrieval
  """

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Workspaces.{Queries, WorkspaceMember}

  @doc """
  Finds a workspace and verifies the user is a member.

  Returns the workspace if the user is a member, nil otherwise.

  ## Examples

      iex> get_workspace_for_user(user, workspace_id)
      %Workspace{}

      iex> get_workspace_for_user(non_member, workspace_id)
      nil

  """
  def get_workspace_for_user(%User{} = user, workspace_id, repo \\ Repo) do
    Queries.for_user_by_id(user, workspace_id)
    |> repo.one()
  end

  @doc """
  Finds a workspace by slug and verifies the user is a member.

  Returns the workspace if the user is a member, nil otherwise.

  ## Examples

      iex> get_workspace_for_user_by_slug(user, "my-workspace")
      %Workspace{}

      iex> get_workspace_for_user_by_slug(non_member, "my-workspace")
      nil

  """
  def get_workspace_for_user_by_slug(%User{} = user, slug, repo \\ Repo) do
    Queries.for_user_by_slug(user, slug)
    |> repo.one()
  end

  @doc """
  Finds a workspace by slug with the current user's member record preloaded.

  Returns a tuple of {workspace, member} if the user is a member, nil otherwise.
  This is more efficient than calling get_workspace_for_user_by_slug/2 followed
  by get_member/2 as it uses a single query instead of two.

  ## Examples

      iex> get_workspace_and_member_by_slug(user, "my-workspace")
      {%Workspace{}, %WorkspaceMember{}}

      iex> get_workspace_and_member_by_slug(non_member, "my-workspace")
      nil

  """
  def get_workspace_and_member_by_slug(%User{} = user, slug, repo \\ Repo) do
    case Queries.for_user_by_slug_with_member(user, slug) |> repo.one() do
      nil ->
        nil

      workspace ->
        # workspace_members will contain only the current user's member record
        # because the join filtered by user_id
        member = List.first(workspace.workspace_members)
        {workspace, member}
    end
  end

  @doc """
  Checks if a workspace exists.

  ## Examples

      iex> workspace_exists?(workspace_id)
      true

      iex> workspace_exists?(invalid_id)
      false

  """
  def workspace_exists?(workspace_id, repo \\ Repo) do
    case Queries.exists?(workspace_id) |> repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end

  @doc """
  Gets a user's workspace member record.

  ## Examples

      iex> get_member(user, workspace_id)
      %WorkspaceMember{role: :owner}

      iex> get_member(non_member, workspace_id)
      nil

  """
  def get_member(%User{} = user, workspace_id, repo \\ Repo) do
    Queries.get_member(user, workspace_id)
    |> repo.one()
  end

  @doc """
  Finds a workspace member by email (case-insensitive).

  ## Examples

      iex> find_member_by_email(workspace_id, "user@example.com")
      %WorkspaceMember{}

      iex> find_member_by_email(workspace_id, "nonexistent@example.com")
      nil

  """
  def find_member_by_email(workspace_id, email, repo \\ Repo) do
    Queries.find_member_by_email(workspace_id, email)
    |> repo.one()
  end

  @doc """
  Checks if an email is already a member of a workspace.

  ## Examples

      iex> email_is_member?(workspace_id, "member@example.com")
      true

      iex> email_is_member?(workspace_id, "new@example.com")
      false

  """
  def email_is_member?(workspace_id, email, repo \\ Repo) do
    case find_member_by_email(workspace_id, email, repo) do
      nil -> false
      _member -> true
    end
  end

  @doc """
  Lists all members of a workspace.

  ## Examples

      iex> list_members(workspace_id)
      [%WorkspaceMember{}, ...]

  """
  def list_members(workspace_id, repo \\ Repo) do
    Queries.list_members(workspace_id)
    |> repo.all()
  end

  @doc """
  Checks if a workspace slug already exists.

  ## Examples

      iex> slug_exists?("my-workspace", nil)
      true

      iex> slug_exists?("new-slug", nil)
      false

  """
  def slug_exists?(slug, excluding_id \\ nil, repo \\ Repo) do
    import Ecto.Query

    query =
      from(w in Jarga.Workspaces.Workspace,
        where: w.slug == ^slug
      )

    query =
      if excluding_id do
        from(w in query, where: w.id != ^excluding_id)
      else
        query
      end

    repo.exists?(query)
  end

  @doc """
  Adds a member to a workspace (for testing purposes).

  ## Parameters
    - workspace_id: ID of the workspace
    - user_id: ID of the user to add
    - email: User's email
    - role: Member role (:owner, :admin, or :member)

  ## Returns
    - `{:ok, workspace_member}` if successful
    - `{:error, changeset}` if validation fails

  ## Examples

      iex> add_member(workspace_id, user_id, "user@example.com", :member)
      {:ok, %WorkspaceMember{}}

  """
  def add_member(workspace_id, user_id, email, role, repo \\ Repo) do
    %WorkspaceMember{}
    |> WorkspaceMember.changeset(%{
      workspace_id: workspace_id,
      user_id: user_id,
      email: email,
      role: role
    })
    |> repo.insert()
  end

  @doc """
  Checks if a user is a member of a workspace.

  ## Examples

      iex> member?(user_id, workspace_id)
      true

      iex> member?(user_id, other_workspace_id)
      false

  """
  def member?(user_id, workspace_id, repo \\ Repo) do
    query =
      from(wm in WorkspaceMember,
        where: wm.user_id == ^user_id and wm.workspace_id == ^workspace_id
      )

    repo.exists?(query)
  end
end
