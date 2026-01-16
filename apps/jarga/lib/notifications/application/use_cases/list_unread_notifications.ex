defmodule Jarga.Notifications.Application.UseCases.ListUnreadNotifications do
  @moduledoc """
  Lists unread notifications for a user.
  """

  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Lists unread notifications for a user, ordered by most recent.

  ## Examples

      iex> execute(user_id)
      [%Notification{}, ...]
  """
  def execute(user_id) do
    NotificationRepository.list_unread_by_user(user_id)
  end
end
