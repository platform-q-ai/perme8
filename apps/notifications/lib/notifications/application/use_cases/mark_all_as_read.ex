defmodule Notifications.Application.UseCases.MarkAllAsRead do
  @moduledoc """
  Marks all notifications as read for a user.
  """

  @default_notification_repository Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Marks all unread notifications as read for a user.

  Returns `{:ok, count}` where count is the number of notifications marked as read.

  ## Options
    * `:notification_repository` - Repository module (default: NotificationRepository)
  """
  def execute(user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notification_repository.mark_all_as_read(user_id)
  end
end
