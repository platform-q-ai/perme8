defmodule Notifications.Application.UseCases.ListUnreadNotifications do
  @moduledoc """
  Lists unread notifications for a user.
  """

  @default_notification_repository Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Lists unread notifications for a user, ordered by most recent.

  ## Options
    * `:limit` - Maximum number of notifications to return
    * `:notification_repository` - Repository module (default: NotificationRepository)
  """
  def execute(user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notification_repository.list_unread_by_user(user_id, opts)
  end
end
