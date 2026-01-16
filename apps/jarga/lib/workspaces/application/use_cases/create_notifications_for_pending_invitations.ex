defmodule Jarga.Workspaces.Application.UseCases.CreateNotificationsForPendingInvitations do
  @moduledoc """
  Use case for creating notifications for pending workspace invitations.

  When a new user signs up after being invited to a workspace, this use case
  creates notifications for all pending invitations so the user can accept them.

  ## Responsibilities

  - Find all pending invitations for the user's email
  - Create a notification for each pending invitation
  - Send broadcasts via PubSub for real-time updates

  ## Dependencies

  This use case coordinates between Workspaces and Notifications contexts.
  """

  @behaviour Jarga.Workspaces.Application.UseCases.UseCase

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Infrastructure.Repositories.MembershipRepository
  alias Jarga.Workspaces.Infrastructure.Notifiers.PubSubNotifier

  @doc """
  Executes the create notifications for pending invitations use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user who just confirmed their email

  - `opts` - Keyword list of options:
    - `:pubsub_notifier` - Optional PubSub notifier module (default: PubSubNotifier)

  ## Returns

  - `{:ok, notifications}` - List of created notifications
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    pubsub_notifier = Keyword.get(opts, :pubsub_notifier, PubSubNotifier)
    %{user: %User{} = user} = params

    result =
      MembershipRepository.transact(fn ->
        # Find all pending invitations for this user's email (case-insensitive)
        pending_invitations = Workspaces.list_pending_invitations_with_details(user.email)

        {:ok, pending_invitations}
      end)

    # Broadcast AFTER transaction commits to avoid race conditions
    case result do
      {:ok, pending_invitations} ->
        Enum.each(pending_invitations, fn invitation ->
          broadcast_invitation_notification(user, invitation, pubsub_notifier)
        end)

        {:ok, []}

      error ->
        error
    end
  end

  defp broadcast_invitation_notification(user, invitation_schema, pubsub_notifier) do
    inviter_name = get_inviter_name(invitation_schema.inviter)

    pubsub_notifier.broadcast_invitation_created(
      user.id,
      invitation_schema.workspace_id,
      invitation_schema.workspace.name,
      inviter_name,
      to_string(invitation_schema.role)
    )
  end

  defp get_inviter_name(nil), do: "Someone"

  defp get_inviter_name(inviter) do
    "#{inviter.first_name} #{inviter.last_name}"
  end
end
