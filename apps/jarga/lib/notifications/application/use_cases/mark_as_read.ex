defmodule Jarga.Notifications.Application.UseCases.MarkAsRead do
  @moduledoc """
  Marks a notification as read.
  """

  @default_notification_repository Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Marks a notification as read for a user.

  Returns `{:ok, notification}` if successful.
  Returns `{:error, :not_found}` if notification doesn't exist or doesn't belong to user.

  ## Options
  - `:notification_repository` - Repository module (default: NotificationRepository)

  ## Examples

      iex> execute(notification_id, user_id)
      {:ok, %Notification{read: true}}

      iex> execute(non_existent_id, user_id)
      {:error, :not_found}
  """
  def execute(notification_id, user_id, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    case notification_repository.get_by_user(notification_id, user_id) do
      nil ->
        {:error, :not_found}

      notification ->
        notification_repository.mark_as_read(notification)
    end
  end
end
