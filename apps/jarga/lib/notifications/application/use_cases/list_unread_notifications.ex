defmodule Jarga.Notifications.Application.UseCases.ListUnreadNotifications do
  @moduledoc """
  Lists unread notifications for a user.
  """

  @default_notification_repository Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Lists unread notifications for a user, ordered by most recent.

  ## Options
  - `:notification_repository` - Repository module (default: NotificationRepository)

  ## Examples

      iex> execute(user_id)
      [%Notification{}, ...]
  """
  def execute(user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notification_repository.list_unread_by_user(user_id)
  end
end
