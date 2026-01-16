defmodule Jarga.Notifications.Application.UseCases.MarkAsRead do
  @moduledoc """
  Marks a notification as read.
  """

  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Marks a notification as read for a user.

  Returns `{:ok, notification}` if successful.
  Returns `{:error, :not_found}` if notification doesn't exist or doesn't belong to user.

  ## Examples

      iex> execute(notification_id, user_id)
      {:ok, %Notification{read: true}}

      iex> execute(non_existent_id, user_id)
      {:error, :not_found}
  """
  def execute(notification_id, user_id) do
    case NotificationRepository.get_by_user(notification_id, user_id) do
      nil ->
        {:error, :not_found}

      notification ->
        NotificationRepository.mark_as_read(notification)
    end
  end
end
