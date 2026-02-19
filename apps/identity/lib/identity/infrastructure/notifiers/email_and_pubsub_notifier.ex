defmodule Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier do
  @moduledoc """
  Default implementation of NotificationService that sends both email and structured event notifications.

  This implementation:
  - Sends email notifications via WorkspaceNotifier
  - Emits structured domain events via EventBus for real-time updates
  - Uses configurable URL builders for links in emails
  """

  @behaviour Identity.Application.Behaviours.NotificationServiceBehaviour

  alias Identity.Domain.Entities.User
  alias Identity.Domain.Entities.Workspace
  alias Identity.Infrastructure.Notifiers.WorkspaceNotifier
  alias Identity.Domain.Events.{WorkspaceUpdated, MemberRemoved, WorkspaceInvitationNotified}

  @impl true
  def notify_existing_user(%User{} = user, %Workspace{} = workspace, %User{} = inviter) do
    # Send email notification
    workspace_url = build_workspace_url(workspace.id)
    WorkspaceNotifier.deliver_invitation_to_existing_user(user, workspace, inviter, workspace_url)

    # Emit structured event for EventBus
    event_bus().emit(
      WorkspaceInvitationNotified.new(%{
        aggregate_id: "#{workspace.id}:#{user.id}",
        actor_id: inviter.id,
        workspace_id: workspace.id,
        target_user_id: user.id,
        workspace_name: workspace.name,
        invited_by_name: inviter.first_name,
        role: "member"
      })
    )

    :ok
  end

  @impl true
  def notify_new_user(email, %Workspace{} = workspace, %User{} = inviter) do
    # Send invitation email
    signup_url = build_signup_url()
    WorkspaceNotifier.deliver_invitation_to_new_user(email, workspace, inviter, signup_url)

    :ok
  end

  @impl true
  def notify_user_removed(%User{} = user, %Workspace{} = workspace) do
    # Emit structured event for EventBus
    event_bus().emit(
      MemberRemoved.new(%{
        aggregate_id: "#{workspace.id}:#{user.id}",
        actor_id: "system",
        workspace_id: workspace.id,
        target_user_id: user.id
      })
    )

    :ok
  end

  @impl true
  def notify_workspace_updated(%Workspace{} = workspace) do
    # Emit structured event for EventBus
    event_bus().emit(
      WorkspaceUpdated.new(%{
        aggregate_id: workspace.id,
        actor_id: "system",
        workspace_id: workspace.id,
        name: workspace.name
      })
    )

    :ok
  end

  # URL builders - configured via identity app config, falls back to jarga config
  defp build_workspace_url(workspace_id) do
    base_url =
      Application.get_env(:identity, :base_url) ||
        Application.get_env(:jarga, :base_url, "http://localhost:4000")

    "#{base_url}/app/workspaces/#{workspace_id}"
  end

  defp build_signup_url do
    base_url =
      Application.get_env(:identity, :base_url) ||
        Application.get_env(:jarga, :base_url, "http://localhost:4000")

    "#{base_url}/users/register"
  end

  # Resolved at runtime to avoid compile-time dependency on jarga app
  defp event_bus do
    Application.get_env(:identity, :event_bus, Perme8.Events.EventBus)
  end
end
