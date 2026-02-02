defmodule Jarga.Notifications.Application.UseCases.GetUnreadCount do
  @moduledoc """
  Gets the count of unread notifications for a user.
  """

  @default_notification_repository Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Returns the number of unread notifications for a user.

  ## Options
  - `:notification_repository` - Repository module (default: NotificationRepository)

  ## Examples

      iex> execute(user_id)
      5
  """
  def execute(user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notification_repository.count_unread_by_user(user_id)
  end
end
