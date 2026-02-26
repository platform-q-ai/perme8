defmodule Notifications.Application.UseCases.GetNotification do
  @moduledoc """
  Gets a notification by ID for a specific user.
  """

  @default_notification_repository Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Returns the notification if it belongs to the user, nil otherwise.

  ## Options
    * `:notification_repository` - Repository module (default: NotificationRepository)
  """
  def execute(notification_id, user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notification_repository.get_by_user(notification_id, user_id)
  end
end
