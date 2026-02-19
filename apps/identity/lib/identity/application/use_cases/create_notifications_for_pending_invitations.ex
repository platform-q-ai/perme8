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

  alias Identity.Domain.Events.MemberInvited

  @default_membership_repository Identity.Infrastructure.Repositories.MembershipRepository
  @default_queries Identity.Infrastructure.Queries.WorkspaceQueries
  @default_repo Identity.Repo
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Executes the create notifications for pending invitations use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user who just confirmed their email

  - `opts` - Keyword list of options:
    - `:event_bus` - Optional event bus module (default: Perme8.Events.EventBus)
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
          emit_member_invited_event(user, invitation, event_bus)
        end)

        {:ok, []}

      error ->
        error
    end
  end

  defp emit_member_invited_event(user, invitation_schema, event_bus) do
    inviter_name = get_inviter_name(invitation_schema.inviter)

    # Emit structured domain event
    event =
      MemberInvited.new(%{
        aggregate_id: "#{invitation_schema.workspace_id}:#{user.id}",
        # Fallback to invitee's ID when inviter is unknown (legacy invitations
        # without invited_by). The invited_by_name will be "Someone" via
        # get_inviter_name(nil) in this case.
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
