defmodule Jarga.Workspaces do
  @moduledoc """
  The Workspaces context.

  Handles workspace creation, management, and membership.
  This module follows Clean Architecture patterns by delegating to:
  - Query Objects (infrastructure layer) for data access
  - Policies (domain layer) for business rules
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Main context module and shared types (Workspace)
  # Internal modules (WorkspaceMember, Queries, Policies) remain private
  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Repo, Jarga.Mailer],
    exports: [{Workspace, []}]

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Accounts.User
  alias Jarga.Workspaces.{Workspace, WorkspaceMember, Queries}
  alias Jarga.Workspaces.Infrastructure.MembershipRepository
  alias Jarga.Workspaces.UseCases.{InviteMember, ChangeMemberRole, RemoveMember}
  alias Jarga.Workspaces.Services.EmailAndPubSubNotifier

  @doc """
  Returns the list of workspaces for a given user.

  Only returns non-archived workspaces where the user is a member.

  ## Examples

      iex> list_workspaces_for_user(user)
      [%Workspace{}, ...]

  """
  def list_workspaces_for_user(%User{} = user) do
    Queries.base()
    |> Queries.for_user(user)
    |> Queries.active()
    |> Queries.ordered()
    |> Repo.all()
  end

  @doc """
  Creates a workspace for a user.

  Automatically adds the creating user as an owner of the workspace.

  ## Examples

      iex> create_workspace(user, %{name: "My Workspace"})
      {:ok, %Workspace{}}

      iex> create_workspace(user, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_workspace(%User{} = user, attrs) do
    Repo.transact(fn ->
      with {:ok, workspace} <- create_workspace_record(attrs),
           {:ok, _member} <- add_member_as_owner(workspace, user) do
        {:ok, workspace}
      end
    end)
  end

  defp create_workspace_record(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  defp add_member_as_owner(workspace, user) do
    now = DateTime.utc_now()

    %WorkspaceMember{}
    |> WorkspaceMember.changeset(%{
      workspace_id: workspace.id,
      user_id: user.id,
      email: user.email,
      role: :owner,
      invited_at: now,
      joined_at: now
    })
    |> Repo.insert()
  end

  @doc """
  Gets a single workspace for a user.

  Returns `{:ok, workspace}` if the user is a member, or an error tuple otherwise.

  ## Returns

  - `{:ok, workspace}` - User is a member of the workspace
  - `{:error, :unauthorized}` - Workspace exists but user is not a member
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> get_workspace(user, workspace_id)
      {:ok, %Workspace{}}

      iex> get_workspace(user, non_member_workspace_id)
      {:error, :unauthorized}

      iex> get_workspace(user, "non-existent-id")
      {:error, :workspace_not_found}

  """
  def get_workspace(%User{} = user, id) do
    case MembershipRepository.get_workspace_for_user(user, id) do
      nil ->
        if MembershipRepository.workspace_exists?(id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end

  @doc """
  Gets a single workspace for a user.

  Raises `Ecto.NoResultsError` if the Workspace does not exist or
  if the user is not a member of the workspace.

  ## Examples

      iex> get_workspace!(user, workspace_id)
      %Workspace{}

      iex> get_workspace!(user, "non-existent-id")
      ** (Ecto.NoResultsError)

  """
  def get_workspace!(%User{} = user, id) do
    Queries.for_user_by_id(user, id)
    |> Repo.one!()
  end

  @doc """
  Updates a workspace for a user.

  The user must be a member of the workspace to update it.

  ## Examples

      iex> update_workspace(user, workspace_id, %{name: "Updated Name"})
      {:ok, %Workspace{}}

      iex> update_workspace(user, workspace_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_workspace(user, non_member_workspace_id, %{name: "Updated"})
      {:error, :unauthorized}

  """
  def update_workspace(%User{} = user, workspace_id, attrs) do
    case get_workspace(user, workspace_id) do
      {:ok, workspace} ->
        workspace
        |> Workspace.changeset(attrs)
        |> Repo.update()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a workspace for a user.

  The user must be a member of the workspace to delete it.
  Deleting a workspace will cascade delete all associated projects.

  ## Examples

      iex> delete_workspace(user, workspace_id)
      {:ok, %Workspace{}}

      iex> delete_workspace(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def delete_workspace(%User{} = user, workspace_id) do
    case get_workspace(user, workspace_id) do
      {:ok, workspace} ->
        Repo.delete(workspace)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies that a user is a member of a workspace.

  This is a public API for other contexts to verify workspace membership.

  ## Returns

  - `{:ok, workspace}` - User is a member of the workspace
  - `{:error, :unauthorized}` - Workspace exists but user is not a member
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> verify_membership(user, workspace_id)
      {:ok, %Workspace{}}

      iex> verify_membership(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def verify_membership(%User{} = user, workspace_id) do
    get_workspace(user, workspace_id)
  end

  @doc """
  Invites a user to join a workspace via email.

  The inviter must be a member of the workspace. Only admin, member, and guest
  roles are allowed (owner role is reserved for workspace creators).

  If the user exists in the system, they are immediately added as a member.
  If the user doesn't exist, a pending invitation is created.

  ## Returns

  - `{:ok, :member_added, member}` - Existing user was added to workspace
  - `{:ok, :invitation_sent, invitation}` - Pending invitation created for non-existing user
  - `{:error, :invalid_role}` - Attempted to invite with :owner role
  - `{:error, :already_member}` - User is already a member of the workspace
  - `{:error, :unauthorized}` - Inviter is not a member of the workspace
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> invite_member(owner, workspace_id, "user@example.com", :admin)
      {:ok, :member_added, %WorkspaceMember{}}

      iex> invite_member(owner, workspace_id, "newuser@example.com", :member)
      {:ok, :invitation_sent, %WorkspaceMember{}}

  """
  def invite_member(%User{} = inviter, workspace_id, email, role, opts \\ []) do
    # Get notifier from opts or use default
    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    params = %{
      inviter: inviter,
      workspace_id: workspace_id,
      email: email,
      role: role
    }

    # Delegate to use case
    InviteMember.execute(params, notifier: notifier)
  end

  @doc """
  Lists all members of a workspace.

  Includes both active members (with user_id and joined_at) and pending
  invitations (without user_id and joined_at).

  ## Examples

      iex> list_members(workspace_id)
      [%WorkspaceMember{}, ...]

  """
  def list_members(workspace_id) do
    MembershipRepository.list_members(workspace_id)
  end

  @doc """
  Changes a workspace member's role.

  The actor must be a member of the workspace. Cannot change the owner's role,
  and cannot assign the owner role.

  ## Returns

  - `{:ok, updated_member}` - Role changed successfully
  - `{:error, :invalid_role}` - Attempted to assign owner role
  - `{:error, :cannot_change_owner_role}` - Attempted to change owner's role
  - `{:error, :member_not_found}` - Member doesn't exist
  - `{:error, :unauthorized}` - Actor is not a member of the workspace
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> change_member_role(admin, workspace_id, "user@example.com", :admin)
      {:ok, %WorkspaceMember{}}

  """
  def change_member_role(%User{} = actor, workspace_id, member_email, new_role) do
    params = %{
      actor: actor,
      workspace_id: workspace_id,
      member_email: member_email,
      new_role: new_role
    }

    ChangeMemberRole.execute(params)
  end

  @doc """
  Removes a member from a workspace.

  The actor must be a member of the workspace. Cannot remove the owner.
  Works for both active members and pending invitations.

  ## Returns

  - `{:ok, deleted_member}` - Member removed successfully
  - `{:error, :cannot_remove_owner}` - Attempted to remove the owner
  - `{:error, :member_not_found}` - Member doesn't exist
  - `{:error, :unauthorized}` - Actor is not a member of the workspace
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> remove_member(admin, workspace_id, "user@example.com")
      {:ok, %WorkspaceMember{}}

  """
  def remove_member(%User{} = actor, workspace_id, member_email) do
    params = %{
      actor: actor,
      workspace_id: workspace_id,
      member_email: member_email
    }

    RemoveMember.execute(params)
  end
end
