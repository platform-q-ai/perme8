defmodule Jarga.Notifications.Application.UseCases.DeclineWorkspaceInvitation do
  @moduledoc """
  Declines a workspace invitation from a notification.

  This use case:
  1. Validates the notification exists and belongs to the user
  2. Extracts workspace data from the notification
  3. Deletes the workspace_member pending invitation record
  4. Marks the notification as action_taken
  """

  alias Jarga.Workspaces
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  alias Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier

  @doc """
  Declines a workspace invitation.

  Returns `{:ok, notification}` if successful.
  Returns `{:error, :not_found}` if notification doesn't exist or doesn't belong to user.
  Returns `{:error, :invalid_notification_type}` if notification is not a workspace_invitation.
  Returns `{:error, :already_actioned}` if invitation was already accepted or declined.

  ## Options
  - `:notifier` - Module implementing notification broadcasting (default: PubSubNotifier)

  ## Examples

      iex> execute(notification_id, user_id)
      {:ok, %Notification{}}
  """
  def execute(notification_id, user_id, opts \\ []) do
    notifier = Keyword.get(opts, :notifier, PubSubNotifier)

    result =
      NotificationRepository.transact(fn ->
        with {:ok, notification} <- get_notification(notification_id, user_id),
             :ok <- validate_notification_type(notification),
             :ok <- check_not_already_actioned(notification),
             :ok <- decline_invitation(notification, user_id),
             {:ok, notification} <- mark_notification_action_taken(notification) do
          mark_notification_as_read(notification)
        end
      end)

    # Broadcast AFTER transaction commits
    case result do
      {:ok, notification} ->
        workspace_id = notification.data["workspace_id"]
        notifier.broadcast_invitation_declined(notification.user_id, workspace_id)
        {:ok, notification}

      error ->
        error
    end
  end

  defp get_notification(notification_id, user_id) do
    case NotificationRepository.get_by_user(notification_id, user_id) do
      nil -> {:error, :not_found}
      notification -> {:ok, notification}
    end
  end

  defp validate_notification_type(notification) do
    if notification.type == "workspace_invitation" do
      :ok
    else
      {:error, :invalid_notification_type}
    end
  end

  defp check_not_already_actioned(notification) do
    if is_nil(notification.action_taken_at) do
      :ok
    else
      {:error, :already_actioned}
    end
  end

  defp decline_invitation(notification, user_id) do
    workspace_id = notification.data["workspace_id"]
    Workspaces.decline_invitation_by_workspace(workspace_id, user_id)
  end

  defp mark_notification_action_taken(notification) do
    NotificationRepository.mark_action_taken(notification, "declined")
  end

  defp mark_notification_as_read(notification) do
    NotificationRepository.mark_as_read(notification)
  end
end
