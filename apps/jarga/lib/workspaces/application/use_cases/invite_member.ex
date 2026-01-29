defmodule Jarga.Workspaces.Application.UseCases.InviteMember do
  @moduledoc """
  Use case for inviting a member to a workspace.

  This use case orchestrates the process of inviting a user to join a workspace,
  handling both existing users (immediate membership) and new users (pending invitations).

  ## Responsibilities

  - Validate inviter has permission
  - Validate role is allowed for invitation
  - Check if email is already a member
  - Add existing users as immediate members
  - Create pending invitations for new users
  - Send appropriate notifications

  ## Dependencies

  This use case accepts dependencies via options for testability:
  - `:notifier` - Module implementing notification callbacks
  """

  @behaviour Jarga.Workspaces.Application.UseCases.UseCase

  alias Jarga.Accounts
  alias Jarga.Workspaces.Application.Policies.MembershipPolicy
  alias Jarga.Workspaces.Application.Policies.PermissionsPolicy

  @default_membership_repository Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository
  @default_pubsub_notifier Jarga.Workspaces.Infrastructure.Notifiers.PubSubNotifier

  @doc """
  Executes the invite member use case.

  ## Parameters

  - `params` - Map containing:
    - `:inviter` - User performing the invitation
    - `:workspace_id` - ID of the workspace
    - `:email` - Email of the person to invite
    - `:role` - Role to assign (:admin, :member, or :guest)

  - `opts` - Keyword list of options:
    - `:notifier` - Optional email notifier module (default: uses real notifier)
    - `:pubsub_notifier` - Optional PubSub notifier module (default: PubSubNotifier)

  ## Returns

  - `{:ok, {:member_added, member}}` - Existing user added successfully
  - `{:ok, {:invitation_sent, invitation}}` - Pending invitation created
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      inviter: inviter,
      workspace_id: workspace_id,
      email: email,
      role: role
    } = params

    membership_repository =
      Keyword.get(opts, :membership_repository, @default_membership_repository)

    notifier = Keyword.get(opts, :notifier)
    pubsub_notifier = Keyword.get(opts, :pubsub_notifier, @default_pubsub_notifier)

    with :ok <- validate_role(role),
         {:ok, workspace} <-
           verify_inviter_membership(inviter, workspace_id, membership_repository),
         {:ok, inviter_member} <- get_inviter_member(inviter, workspace_id, membership_repository),
         :ok <- check_inviter_permission(inviter_member),
         :ok <- check_not_already_member(workspace_id, email, membership_repository),
         user <- find_user_by_email_case_insensitive(email) do
      # Always create pending invitation (requires acceptance via notification)
      create_pending_invitation(
        workspace,
        email,
        role,
        inviter,
        user,
        notifier,
        pubsub_notifier,
        membership_repository
      )
    end
  end

  # Apply domain policy: validate role is allowed for invitation
  defp validate_role(role) do
    if MembershipPolicy.valid_invitation_role?(role) do
      :ok
    else
      {:error, :invalid_role}
    end
  end

  # Use infrastructure repository: verify inviter is a member
  defp verify_inviter_membership(inviter, workspace_id, membership_repository) do
    case membership_repository.get_workspace_for_user(inviter, workspace_id) do
      nil ->
        # Check if workspace exists to provide meaningful error
        if membership_repository.workspace_exists?(workspace_id) do
          {:error, :unauthorized}
        else
          {:error, :workspace_not_found}
        end

      workspace ->
        {:ok, workspace}
    end
  end

  # Get inviter's membership record
  defp get_inviter_member(inviter, workspace_id, membership_repository) do
    case membership_repository.get_member(inviter, workspace_id) do
      nil -> {:error, :unauthorized}
      member -> {:ok, member}
    end
  end

  # Check if inviter has permission to invite members
  defp check_inviter_permission(inviter_member) do
    if PermissionsPolicy.can?(inviter_member.role, :invite_member) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  # Use infrastructure repository: check if email is already a member
  defp check_not_already_member(workspace_id, email, membership_repository) do
    if membership_repository.email_is_member?(workspace_id, email) do
      {:error, :already_member}
    else
      :ok
    end
  end

  defp find_user_by_email_case_insensitive(email) do
    # Delegate to Accounts context - fixed Credo violation
    Accounts.get_user_by_email_case_insensitive(email)
  end

  defp create_pending_invitation(
         workspace,
         email,
         role,
         inviter,
         user,
         notifier,
         pubsub_notifier,
         membership_repository
       ) do
    result =
      membership_repository.transact(fn ->
        # Create workspace_member record (pending invitation)
        attrs = %{
          workspace_id: workspace.id,
          user_id: nil,
          email: email,
          role: role,
          invited_by: inviter.id,
          invited_at: DateTime.utc_now() |> DateTime.truncate(:second),
          joined_at: nil
        }

        case create_workspace_member(attrs, membership_repository) do
          {:ok, invitation} ->
            # Send email notifications if notifier is provided
            send_email_notification(notifier, user, email, workspace, inviter)

            {:ok, invitation}

          error ->
            error
        end
      end)

    # Broadcast AFTER transaction commits to avoid race conditions
    case result do
      {:ok, invitation} ->
        maybe_create_notification(user, workspace, role, inviter, pubsub_notifier)
        {:ok, {:invitation_sent, invitation}}

      error ->
        error
    end
  end

  defp create_workspace_member(attrs, membership_repository) do
    membership_repository.create_member(attrs)
  end

  defp maybe_create_notification(nil, _workspace, _role, _inviter, _pubsub_notifier),
    do: {:ok, nil}

  defp maybe_create_notification(user, workspace, role, inviter, pubsub_notifier) do
    # Broadcast event for notification creation (existing users only)
    inviter_name = "#{inviter.first_name} #{inviter.last_name}"

    pubsub_notifier.broadcast_invitation_created(
      user.id,
      workspace.id,
      workspace.name,
      inviter_name,
      to_string(role)
    )

    {:ok, nil}
  end

  defp send_email_notification(nil, _user, _email, _workspace, _inviter), do: :ok

  defp send_email_notification(notifier, nil, email, workspace, inviter) do
    notifier.notify_new_user(email, workspace, inviter)
  end

  defp send_email_notification(notifier, user, _email, workspace, inviter) do
    notifier.notify_existing_user(user, workspace, inviter)
  end
end
