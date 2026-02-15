defmodule Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier do
  @moduledoc """
  Default implementation of NotificationService that sends both email and in-app notifications.

  This implementation:
  - Sends email notifications via WorkspaceNotifier
  - Broadcasts in-app notifications via Phoenix.PubSub
  - Uses configurable URL builders for links in emails
  """

  @behaviour Identity.Application.Behaviours.NotificationServiceBehaviour

  alias Identity.Domain.Entities.User
  alias Identity.Domain.Entities.Workspace
  alias Identity.Infrastructure.Notifiers.WorkspaceNotifier

  @pubsub Application.compile_env(:identity, :pubsub_module, Jarga.PubSub)

  @impl true
  def notify_existing_user(%User{} = user, %Workspace{} = workspace, %User{} = inviter) do
    # Send email notification
    workspace_url = build_workspace_url(workspace.id)
    WorkspaceNotifier.deliver_invitation_to_existing_user(user, workspace, inviter, workspace_url)

    # Broadcast in-app notification via PubSub
    Phoenix.PubSub.broadcast(
      @pubsub,
      "user:#{user.id}",
      {:workspace_invitation, workspace.id, workspace.name, inviter.first_name}
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
    # Broadcast in-app notification via PubSub
    Phoenix.PubSub.broadcast(
      @pubsub,
      "user:#{user.id}",
      {:workspace_removed, workspace.id}
    )

    :ok
  end

  @impl true
  def notify_workspace_updated(%Workspace{} = workspace) do
    # Broadcast in-app notification via PubSub to all workspace members
    Phoenix.PubSub.broadcast(
      @pubsub,
      "workspace:#{workspace.id}",
      {:workspace_updated, workspace.id, workspace.name}
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
end
