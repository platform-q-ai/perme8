defmodule Jarga.Workspaces.Infrastructure.Notifiers.PubSubNotifier do
  @moduledoc """
  PubSub notification service for broadcasting workspace invitation events.

  Uses Phoenix PubSub to broadcast real-time updates for workspace invitations.
  """

  @doc """
  Broadcasts a workspace invitation created event.

  ## Parameters
  - `user_id` - The ID of the user who received the invitation
  - `workspace_id` - The ID of the workspace they were invited to
  - `workspace_name` - The name of the workspace
  - `invited_by_name` - The name of the person who sent the invitation
  - `role` - The role they were invited as
  """
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
end
