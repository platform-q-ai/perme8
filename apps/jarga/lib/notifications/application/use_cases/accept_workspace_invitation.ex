defmodule Jarga.Notifications.Application.UseCases.AcceptWorkspaceInvitation do
  @moduledoc """
  Accepts a workspace invitation from a notification.

  This use case:
  1. Validates the notification exists and belongs to the user
  2. Extracts workspace data from the notification
  3. Updates the workspace_member record to mark the user as joined
  4. Marks the notification as action_taken
  """

  alias Jarga.Notifications.Domain.Events.NotificationActionTaken
  alias Jarga.Workspaces

  @default_notification_repository Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  @default_notifier Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Accepts a workspace invitation.

  Returns `{:ok, workspace_member}` if successful.
  Returns `{:error, :not_found}` if notification doesn't exist or doesn't belong to user.
  Returns `{:error, :invalid_notification_type}` if notification is not a workspace_invitation.
  Returns `{:error, :already_accepted}` if invitation was already accepted.
  Returns `{:error, :invitation_not_found}` if the workspace invitation record doesn't exist.

  ## Options
  - `:notifier` - Module implementing notification broadcasting (default: PubSubNotifier)

  ## Examples

      iex> execute(notification_id, user_id)
      {:ok, %WorkspaceMember{}}
  """
  def execute(notification_id, user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notifier = Keyword.get(opts, :notifier, @default_notifier)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    result =
      notification_repository.transact(fn ->
        with {:ok, notification} <-
               get_notification(notification_id, user_id, notification_repository),
             :ok <- validate_notification_type(notification),
             :ok <- check_not_already_accepted(notification),
             {:ok, workspace_member} <- accept_invitation(notification, user_id),
             {:ok, notification} <-
               mark_notification_action_taken(notification, notification_repository),
             {:ok, _notification} <-
               mark_notification_as_read(notification, notification_repository) do
          {:ok, {workspace_member, notification}}
        end
      end)

    # Broadcast AFTER transaction commits
    case result do
      {:ok, {workspace_member, notification}} ->
        workspace_id = notification.data["workspace_id"]
        notifier.broadcast_workspace_joined(user_id, workspace_id)
        emit_action_taken_event(notification, user_id, "accepted", event_bus)
        {:ok, workspace_member}

      error ->
        error
    end
  end

  defp get_notification(notification_id, user_id, notification_repository) do
    case notification_repository.get_by_user(notification_id, user_id) do
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

  defp check_not_already_accepted(notification) do
    if is_nil(notification.action_taken_at) do
      :ok
    else
      {:error, :already_accepted}
    end
  end

  defp accept_invitation(notification, user_id) do
    workspace_id = notification.data["workspace_id"]
    Workspaces.accept_invitation_by_workspace(workspace_id, user_id)
  end

  defp mark_notification_action_taken(notification, notification_repository) do
    notification_repository.mark_action_taken(notification, "accepted")
  end

  defp mark_notification_as_read(notification, notification_repository) do
    notification_repository.mark_as_read(notification)
  end

  defp emit_action_taken_event(notification, user_id, action, event_bus) do
    event =
      NotificationActionTaken.new(%{
        aggregate_id: notification.id,
        actor_id: user_id,
        notification_id: notification.id,
        user_id: user_id,
        action: action,
        workspace_id: notification.data["workspace_id"]
      })

    event_bus.emit(event)
  end
end
