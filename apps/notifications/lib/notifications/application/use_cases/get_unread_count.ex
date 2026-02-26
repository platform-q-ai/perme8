defmodule Notifications.Application.UseCases.GetUnreadCount do
  @moduledoc """
  Gets the count of unread notifications for a user.
  """

  @default_notification_repository Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Returns the number of unread notifications for a user.

  ## Options
    * `:notification_repository` - Repository module (default: NotificationRepository)
  """
  def execute(user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notification_repository.count_unread_by_user(user_id)
  end
end
