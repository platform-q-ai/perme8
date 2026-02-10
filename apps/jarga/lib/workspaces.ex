defmodule Jarga.Workspaces do
  @moduledoc """
  The Workspaces context.

  Handles workspace creation, management, and membership.
  This module follows Clean Architecture patterns by delegating to:
  - Query Objects (infrastructure layer) for data access
  - Policies (domain layer) for business rules
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Depends on layer boundaries for Clean Architecture enforcement
  # Exports: Domain entities, schemas, and PermissionsPolicy for use by other contexts
  use Boundary,
    top_level?: true,
    deps: [
      # Cross-context dependencies (context + domain layer for entity access)
      Jarga.Accounts,
      Jarga.Accounts.Domain,
      # Same-context layer dependencies
      Jarga.Workspaces.Domain,
      Jarga.Workspaces.Application,
      Jarga.Workspaces.Infrastructure,
      Jarga.Repo,
      Jarga.Mailer
    ],
    exports: [
      {Domain.Entities.Workspace, []},
      {Domain.Entities.WorkspaceMember, []},
      {Infrastructure.Schemas.WorkspaceSchema, []},
      {Infrastructure.Schemas.WorkspaceMemberSchema, []},
      {Application.Policies.PermissionsPolicy, []}
    ]

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Workspaces.Domain.Entities.{Workspace, WorkspaceMember}
  alias Jarga.Workspaces.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}
  alias Jarga.Workspaces.Infrastructure.Queries.Queries
  alias Jarga.Workspaces.Domain.SlugGenerator
  alias Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository

  alias Jarga.Workspaces.Application.UseCases.{
    InviteMember,
    ChangeMemberRole,
    RemoveMember,
    CreateNotificationsForPendingInvitations
  }

  alias Jarga.Workspaces.Infrastructure.Notifiers.EmailAndPubSubNotifier
  alias Jarga.Workspaces.Application.Policies.PermissionsPolicy

  @doc """
  Returns the list of workspaces for a given user.

  Only returns non-archived workspaces where the user is a member.

  ## Examples

      iex> list_workspaces_for_user(user)
      [%Workspace{}, ...]

  """
  def list_workspaces_for_user(%{id: _} = user) do
    Queries.base()
    |> Queries.for_user(user)
    |> Queries.active()
    |> Queries.ordered()
    |> Repo.all()
    |> Enum.map(&Workspace.from_schema/1)
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
    # Generate slug in context before passing to changeset (business logic)
    # Only generate slug if name is present
    name = attrs["name"] || attrs[:name]

    attrs_with_slug =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> then(fn normalized_attrs ->
        if name do
          slug = SlugGenerator.generate(name, &MembershipRepository.slug_exists?/2)
          Map.put(normalized_attrs, "slug", slug)
        else
          normalized_attrs
        end
      end)

    %WorkspaceSchema{}
    |> WorkspaceSchema.changeset(attrs_with_slug)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp add_member_as_owner(workspace, user) do
    now = DateTime.utc_now()

    %WorkspaceMemberSchema{}
    |> WorkspaceMemberSchema.changeset(%{
      workspace_id: workspace.id,
      user_id: user.id,
      email: user.email,
      role: :owner,
      invited_at: now,
      joined_at: now
    })
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
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
    |> Workspace.from_schema()
  end

  @doc """
  Gets a single workspace by slug for a user.

  Returns `{:ok, workspace}` if the user is a member, or an error tuple otherwise.

  ## Returns

  - `{:ok, workspace}` - User is a member of the workspace
  - `{:error, :unauthorized}` - Workspace exists but user is not a member
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> get_workspace_by_slug(user, "my-workspace")
      {:ok, %Workspace{}}

      iex> get_workspace_by_slug(user, "non-member-workspace")
      {:error, :unauthorized}

      iex> get_workspace_by_slug(user, "non-existent-slug")
      {:error, :workspace_not_found}

  """
  def get_workspace_by_slug(%User{} = user, slug) do
    case MembershipRepository.get_workspace_for_user_by_slug(user, slug) do
      nil ->
        # We could check if the workspace exists, but for slugs it's simpler
        # to just return :workspace_not_found since slugs are meant to be user-facing
        {:error, :workspace_not_found}

      workspace ->
        {:ok, workspace}
    end
  end

  @doc """
  Gets a workspace by slug with the current user's member record.

  More efficient than calling get_workspace_by_slug/2 followed by get_member/2
  as it fetches both in a single query.

  Returns `{:ok, workspace, member}` if the user is a member, or
  `{:error, :workspace_not_found}` otherwise.

  ## Examples

      iex> get_workspace_and_member_by_slug(user, "my-workspace")
      {:ok, %Workspace{}, %WorkspaceMember{}}

      iex> get_workspace_and_member_by_slug(user, "nonexistent")
      {:error, :workspace_not_found}

  """
  def get_workspace_and_member_by_slug(%User{} = user, slug) do
    case MembershipRepository.get_workspace_and_member_by_slug(user, slug) do
      nil ->
        {:error, :workspace_not_found}

      {workspace, member} ->
        {:ok, workspace, member}
    end
  end

  @doc """
  Gets a single workspace by slug for a user.

  Raises `Ecto.NoResultsError` if the Workspace does not exist or
  if the user is not a member of the workspace.

  ## Examples

      iex> get_workspace_by_slug!(user, "my-workspace")
      %Workspace{}

      iex> get_workspace_by_slug!(user, "non-existent-slug")
      ** (Ecto.NoResultsError)

  """
  def get_workspace_by_slug!(%User{} = user, slug) do
    Queries.for_user_by_slug(user, slug)
    |> Repo.one!()
    |> Workspace.from_schema()
  end

  @doc """
  Updates a workspace for a user.

  The user must be a member of the workspace with permission to edit it.
  Only admins and owners can edit workspaces.

  ## Examples

      iex> update_workspace(user, workspace_id, %{name: "Updated Name"})
      {:ok, %Workspace{}}

      iex> update_workspace(user, workspace_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

      iex> update_workspace(user, non_member_workspace_id, %{name: "Updated"})
      {:error, :unauthorized}

      iex> update_workspace(guest_user, workspace_id, %{name: "Updated"})
      {:error, :forbidden}

  """
  def update_workspace(%User{} = user, workspace_id, attrs, opts \\ []) do
    # Get notifier from opts or use default
    notifier = Keyword.get(opts, :notifier, EmailAndPubSubNotifier)

    with {:ok, member} <- get_member(user, workspace_id),
         :ok <- authorize_edit_workspace(member.role) do
      case get_workspace(user, workspace_id) do
        {:ok, workspace} ->
          result =
            workspace
            |> WorkspaceSchema.to_schema()
            |> WorkspaceSchema.changeset(attrs)
            |> Repo.update()

          # Notify workspace members via injected notifier
          case result do
            {:ok, schema} ->
              updated_workspace = Workspace.from_schema(schema)
              notifier.notify_workspace_updated(updated_workspace)
              {:ok, updated_workspace}

            error ->
              error
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp authorize_edit_workspace(role) do
    if PermissionsPolicy.can?(role, :edit_workspace) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Deletes a workspace for a user.

  The user must be the owner of the workspace to delete it.
  Only owners can delete workspaces.
  Deleting a workspace will cascade delete all associated projects.

  ## Examples

      iex> delete_workspace(owner, workspace_id)
      {:ok, %Workspace{}}

      iex> delete_workspace(admin, workspace_id)
      {:error, :forbidden}

      iex> delete_workspace(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def delete_workspace(%User{} = user, workspace_id) do
    with {:ok, member} <- get_member(user, workspace_id),
         :ok <- authorize_delete_workspace(member.role) do
      case get_workspace(user, workspace_id) do
        {:ok, workspace} ->
          workspace
          |> WorkspaceSchema.to_schema()
          |> Repo.delete()
          |> case do
            {:ok, schema} -> {:ok, Workspace.from_schema(schema)}
            {:error, changeset} -> {:error, changeset}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp authorize_delete_workspace(role) do
    if PermissionsPolicy.can?(role, :delete_workspace) do
      :ok
    else
      {:error, :forbidden}
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
  Checks if a user is a member of a workspace by workspace ID.

  ## Examples

      iex> member?(user_id, workspace_id)
      true

      iex> member?(user_id, other_workspace_id)
      false

  """
  def member?(user_id, workspace_id) do
    MembershipRepository.member?(user_id, workspace_id)
  end

  @doc """
  Checks if a user is a member of a workspace by workspace slug.

  This function is useful for API key validation where workspace access
  is stored by slug rather than ID.

  ## Examples

      iex> member_by_slug?(user_id, "product-team")
      true

      iex> member_by_slug?(user_id, "other-workspace")
      false

  """
  def member_by_slug?(user_id, workspace_slug) do
    MembershipRepository.member_by_slug?(user_id, workspace_slug)
  end

  @doc """
  Gets a user's workspace member record.

  This is a public API for other contexts to get the user's role in a workspace.

  ## Returns

  - `{:ok, workspace_member}` - User is a member with their member record
  - `{:error, :unauthorized}` - Workspace exists but user is not a member
  - `{:error, :workspace_not_found}` - Workspace does not exist

  ## Examples

      iex> get_member(user, workspace_id)
      {:ok, %WorkspaceMember{role: :owner}}

      iex> get_member(user, non_member_workspace_id)
      {:error, :unauthorized}

  """
  def get_member(%User{} = user, workspace_id) do
    case MembershipRepository.get_member(user, workspace_id) do
      nil ->
        if MembershipRepository.workspace_exists?(workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      member ->
        {:ok, member}
    end
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
  Accepts all pending workspace invitations for a user.

  When a user signs up with an email that has pending workspace invitations,
  this function converts those pending invitations into active memberships.

  ## Returns

  - `{:ok, [workspace_member]}` - List of accepted workspace memberships

  ## Examples

      iex> accept_pending_invitations(user)
      {:ok, [%WorkspaceMember{}, ...]}

      iex> accept_pending_invitations(user_with_no_invitations)
      {:ok, []}

  """
  def accept_pending_invitations(%User{} = user) do
    Repo.transact(fn ->
      # Find all pending invitations for this user's email (case-insensitive)
      pending_invitations =
        Queries.find_pending_invitations_by_email(user.email)
        |> Repo.all()

      # Update each invitation to accept it
      now = DateTime.utc_now()

      accepted =
        Enum.map(pending_invitations, fn invitation ->
          invitation
          |> WorkspaceMemberSchema.changeset(%{
            user_id: user.id,
            joined_at: now
          })
          |> Repo.update!()
          |> WorkspaceMember.from_schema()
        end)

      {:ok, accepted}
    end)
  end

  @doc """
  Accepts a specific workspace invitation for a user.

  Finds a pending invitation (not yet joined) for the given workspace and user,
  and marks it as accepted by setting the user_id and joined_at timestamp.

  ## Returns

  - `{:ok, workspace_member}` - Successfully accepted invitation
  - `{:error, :invitation_not_found}` - No pending invitation found

  ## Examples

      iex> accept_invitation_by_workspace(workspace_id, user_id)
      {:ok, %WorkspaceMember{}}

  """
  def accept_invitation_by_workspace(workspace_id, user_id) do
    Repo.transact(fn ->
      case find_pending_invitation(workspace_id, user_id) do
        {:error, reason} -> {:error, reason}
        {:ok, workspace_member} -> accept_invitation(workspace_member, user_id)
      end
    end)
  end

  defp find_pending_invitation(workspace_id, user_id) do
    case Queries.find_pending_invitation(workspace_id, user_id) |> Repo.one() do
      nil -> {:error, :invitation_not_found}
      workspace_member -> {:ok, workspace_member}
    end
  end

  defp accept_invitation(workspace_member, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    workspace_member
    |> WorkspaceMemberSchema.accept_invitation_changeset(%{
      user_id: user_id,
      joined_at: now
    })
    |> Repo.update()
    |> case do
      {:ok, schema} -> {:ok, WorkspaceMember.from_schema(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Declines a specific workspace invitation for a user.

  Finds and deletes a pending invitation for the given workspace and user.

  ## Returns

  - `:ok` - Successfully declined invitation (or invitation not found)
  - `{:error, changeset}` - Failed to delete invitation

  ## Examples

      iex> decline_invitation_by_workspace(workspace_id, user_id)
      :ok

  """
  def decline_invitation_by_workspace(workspace_id, user_id) do
    # Find and delete the pending workspace_member record
    case Queries.find_pending_invitation(workspace_id, user_id) |> Repo.one() do
      nil ->
        # Invitation not found is OK - might have been deleted already
        :ok

      workspace_member ->
        case Repo.delete(workspace_member) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Lists all pending workspace invitations for a user's email.

  Returns invitations with workspace and inviter associations preloaded.

  ## Examples

      iex> list_pending_invitations_with_details("user@example.com")
      [%WorkspaceMember{workspace: %Workspace{}, inviter: %User{}}, ...]

  """
  def list_pending_invitations_with_details(email) do
    Queries.find_pending_invitations_by_email(email)
    |> Queries.with_workspace_and_inviter()
    |> Repo.all()

    # Return schemas directly to preserve workspace and inviter associations
    # These are needed for notification creation
  end

  @doc """
  Creates notifications for all pending workspace invitations for a user.

  This should be called after a new user confirms their email, to ensure they
  receive notifications for any workspace invitations sent before they signed up.

  ## Examples

      iex> create_notifications_for_pending_invitations(user)
      {:ok, [%Notification{}, ...]}

      iex> create_notifications_for_pending_invitations(user_with_no_invitations)
      {:ok, []}

  """
  def create_notifications_for_pending_invitations(%User{} = user) do
    CreateNotificationsForPendingInvitations.execute(%{user: user})
  end

  # Accept any user-like struct (e.g., Identity.Domain.Entities.User)
  def create_notifications_for_pending_invitations(%{id: _, email: _} = user) do
    CreateNotificationsForPendingInvitations.execute(%{user: user})
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

  @doc """
  Creates a changeset for a new workspace (for form validation).
  """
  def change_workspace do
    WorkspaceSchema.changeset(%WorkspaceSchema{}, %{})
  end

  @doc """
  Creates a changeset for editing a workspace (for form validation).
  """
  def change_workspace(%Workspace{} = workspace, attrs \\ %{}) do
    workspace
    |> WorkspaceSchema.to_schema()
    |> WorkspaceSchema.changeset(attrs)
  end
end
