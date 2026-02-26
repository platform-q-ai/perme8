defmodule Notifications.Application.UseCases.ListNotifications do
  @moduledoc """
  Lists all notifications for a user.
  """

  @default_notification_repository Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Lists notifications for a user, ordered by most recent.

  ## Options
    * `:limit` - Maximum number of notifications to return
    * `:notification_repository` - Repository module (default: NotificationRepository)
  """
  def execute(user_id, opts \\ []) do
    {notification_repository, query_opts} =
      Keyword.pop(opts, :notification_repository, @default_notification_repository)

    notification_repository.list_by_user(user_id, query_opts)
  end
end
