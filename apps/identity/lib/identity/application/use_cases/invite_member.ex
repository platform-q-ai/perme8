defmodule Identity.Application.UseCases.InviteMember do
  @moduledoc """
  Use case for inviting a member to a workspace.

  This use case orchestrates the process of inviting a user to join a workspace,
  handling both existing users (immediate membership) and new users (pending invitations).

  ## Responsibilities

  - Validate inviter has permission
  - Validate role is allowed for invitation
  - Check if email is already a member
  - Create pending invitations for both existing and new users
  - Send invitation emails and emit domain events

  """

  @behaviour Identity.Application.UseCases.UseCase

  alias Identity.Domain.Events.{MemberInvited, WorkspaceInvitationNotified}
  alias Identity.Domain.Policies.MembershipPolicy
  alias Identity.Domain.Policies.WorkspacePermissionsPolicy

  @default_membership_repository Identity.Infrastructure.Repositories.MembershipRepository
  @default_workspace_notifier Identity.Infrastructure.Notifiers.WorkspaceNotifier
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the invite member use case.

  ## Parameters

  - `params` - Map containing:
    - `:inviter` - User performing the invitation
    - `:workspace_id` - ID of the workspace
    - `:email` - Email of the person to invite
    - `:role` - Role to assign (:admin, :member, or :guest)

  - `opts` - Keyword list of options:
    - `:event_bus` - Optional event bus module (default: Perme8.Events.EventBus)
    - `:skip_email` - Skip email sending (for testing, default: false)

  ## Returns

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

    workspace_notifier = Keyword.get(opts, :workspace_notifier, @default_workspace_notifier)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    skip_email = Keyword.get(opts, :skip_email, false)

    deps = %{
      workspace_notifier: workspace_notifier,
      event_bus: event_bus,
      skip_email: skip_email,
      membership_repository: membership_repository
    }

    with :ok <- validate_role(role),
         {:ok, workspace} <-
           verify_inviter_membership(inviter, workspace_id, membership_repository),
         {:ok, inviter_member} <-
           get_inviter_member(inviter, workspace_id, membership_repository),
         :ok <- check_inviter_permission(inviter_member),
         :ok <- check_not_already_member(workspace_id, email, membership_repository),
         user <- find_user_by_email_case_insensitive(email) do
      # Always create pending invitation (requires acceptance via notification)
      create_pending_invitation(workspace, email, role, inviter, user, deps)
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
    if WorkspacePermissionsPolicy.can?(inviter_member.role, :invite_member) do
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
    # Use Identity directly - no cross-app dependency
    Identity.get_user_by_email_case_insensitive(email)
  end

  defp create_pending_invitation(workspace, email, role, inviter, user, deps) do
    %{
      workspace_notifier: workspace_notifier,
      event_bus: event_bus,
      skip_email: skip_email,
      membership_repository: membership_repository
    } = deps

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

        create_workspace_member(attrs, membership_repository)
      end)

    # Side effects AFTER transaction commits to avoid race conditions
    case result do
      {:ok, invitation} ->
        maybe_send_email(skip_email, workspace_notifier, user, email, workspace, inviter, role,
          event_bus: event_bus
        )

        maybe_emit_member_invited(user, workspace, role, inviter, event_bus)
        {:ok, {:invitation_sent, invitation}}

      error ->
        error
    end
  end

  defp create_workspace_member(attrs, membership_repository) do
    membership_repository.create_member(attrs)
  end

  defp maybe_send_email(true, _notifier, _user, _email, _workspace, _inviter, _role, _opts),
    do: :ok

  defp maybe_send_email(false, notifier, user, email, workspace, inviter, role, opts) do
    event_bus = Keyword.get(opts, :event_bus)
    send_email_notification(notifier, user, email, workspace, inviter, role, event_bus)
  end

  defp maybe_emit_member_invited(nil, _workspace, _role, _inviter, _event_bus),
    do: {:ok, nil}

  defp maybe_emit_member_invited(user, workspace, role, inviter, event_bus) do
    inviter_name = "#{inviter.first_name} #{inviter.last_name}"

    # Emit structured domain event
    event =
      MemberInvited.new(%{
        aggregate_id: "#{workspace.id}:#{user.id}",
        actor_id: inviter.id,
        user_id: user.id,
        workspace_id: workspace.id,
        workspace_name: workspace.name,
        invited_by_name: inviter_name,
        role: to_string(role)
      })

    event_bus.emit(event)

    {:ok, nil}
  end

  defp send_email_notification(notifier, nil, email, workspace, inviter, _role, _event_bus) do
    notifier.notify_new_user(email, workspace, inviter)
  end

  defp send_email_notification(notifier, user, _email, workspace, inviter, role, event_bus) do
    notifier.notify_existing_user(user, workspace, inviter)

    # Emit invitation notified event
    inviter_name = "#{inviter.first_name} #{inviter.last_name}"

    event_bus.emit(
      WorkspaceInvitationNotified.new(%{
        aggregate_id: "#{workspace.id}:#{user.id}",
        actor_id: inviter.id,
        workspace_id: workspace.id,
        target_user_id: user.id,
        workspace_name: workspace.name,
        invited_by_name: inviter_name,
        role: to_string(role)
      })
    )
  end
end
