defmodule Identity.Application.UseCases.CreateNotificationsForPendingInvitations do
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

  @behaviour Identity.Application.UseCases.UseCase

  @default_membership_repository Identity.Infrastructure.Repositories.MembershipRepository
  @default_pubsub_notifier Identity.Infrastructure.Notifiers.PubSubNotifier
  @default_queries Identity.Infrastructure.Queries.WorkspaceQueries
  @default_repo Identity.Repo
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the create notifications for pending invitations use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user who just confirmed their email

  - `opts` - Keyword list of options:
    - `:pubsub_notifier` - Optional PubSub notifier module (default: PubSubNotifier)
    - `:queries` - Optional queries module (default: WorkspaceQueries)
    - `:repo` - Optional Ecto repo (default: Identity.Repo)

  ## Returns

  - `{:ok, notifications}` - List of created notifications
  - `{:error, reason}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    membership_repository =
      Keyword.get(opts, :membership_repository, @default_membership_repository)

    pubsub_notifier = Keyword.get(opts, :pubsub_notifier, @default_pubsub_notifier)
    queries = Keyword.get(opts, :queries, @default_queries)
    repo = Keyword.get(opts, :repo, @default_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    %{user: %{id: _, email: _} = user} = params

    result =
      membership_repository.transact(fn ->
        # Find all pending invitations for this user's email (case-insensitive)
        pending_invitations =
          queries.find_pending_invitations_by_email(user.email)
          |> queries.with_workspace_and_inviter()
          |> repo.all()

        {:ok, pending_invitations}
      end)

    # Broadcast AFTER transaction commits to avoid race conditions
    case result do
      {:ok, pending_invitations} ->
        Enum.each(pending_invitations, fn invitation ->
          broadcast_invitation_notification(user, invitation, pubsub_notifier, event_bus)
        end)

        {:ok, []}

      error ->
        error
    end
  end

  defp broadcast_invitation_notification(user, invitation_schema, pubsub_notifier, event_bus) do
    inviter_name = get_inviter_name(invitation_schema.inviter)

    pubsub_notifier.broadcast_invitation_created(
      user.id,
      invitation_schema.workspace_id,
      invitation_schema.workspace.name,
      inviter_name,
      to_string(invitation_schema.role)
    )

    # Emit structured domain event
    event =
      Identity.Domain.Events.MemberInvited.new(%{
        aggregate_id: "#{invitation_schema.workspace_id}:#{user.id}",
        actor_id: invitation_schema.invited_by || user.id,
        user_id: user.id,
        workspace_id: invitation_schema.workspace_id,
        workspace_name: invitation_schema.workspace.name,
        invited_by_name: inviter_name,
        role: to_string(invitation_schema.role)
      })

    event_bus.emit(event)
  end

  defp get_inviter_name(nil), do: "Someone"

  defp get_inviter_name(inviter) do
    "#{inviter.first_name} #{inviter.last_name}"
  end
end
