defmodule Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  PubSub notification service for broadcasting notification-related events.

  Uses Phoenix PubSub to broadcast real-time updates for workspace invitations
  and other notification events.
  """

  @behaviour Jarga.Notifications.Application.Behaviours.PubSubNotifierBehaviour

  @doc """
  Broadcasts a workspace invitation created event.

  ## Parameters
  - `user_id` - The ID of the user who received the invitation
  - `workspace_id` - The ID of the workspace they were invited to
  - `workspace_name` - The name of the workspace
  - `invited_by_name` - The name of the person who sent the invitation
  - `role` - The role they were invited as
  """
  @impl true
  def broadcast_invitation_created(user_id, workspace_id, workspace_name, invited_by_name, role) do
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace_invitations",
      {:workspace_invitation_created,
       %{
         user_id: user_id,
         workspace_id: workspace_id,
         workspace_name: workspace_name,
         invited_by_name: invited_by_name,
         role: role
       }}
    )

    :ok
  end

  @doc """
  Broadcasts a workspace joined event when a user accepts an invitation.

  ## Parameters
  - `user_id` - The ID of the user who joined
  - `workspace_id` - The ID of the workspace they joined
  """
  @impl true
  def broadcast_workspace_joined(user_id, workspace_id) do
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "user:#{user_id}",
      {:workspace_joined, workspace_id}
    )

    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{workspace_id}",
      {:member_joined, user_id}
    )

    :ok
  end

  @doc """
  Broadcasts an invitation declined event.

  ## Parameters
  - `user_id` - The ID of the user who declined
  - `workspace_id` - The ID of the workspace invitation they declined
  """
  @impl true
  def broadcast_invitation_declined(user_id, workspace_id) do
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "workspace:#{workspace_id}",
      {:invitation_declined, user_id}
    )

    :ok
  end

  @doc """
  Broadcasts a new notification event to a user.

  ## Parameters
  - `user_id` - The ID of the user receiving the notification
  - `notification` - The notification struct
  """
  @impl true
  def broadcast_new_notification(user_id, notification) do
    Phoenix.PubSub.broadcast(
      Jarga.PubSub,
      "user:#{user_id}:notifications",
      {:new_notification, notification}
    )

    :ok
  end
end
