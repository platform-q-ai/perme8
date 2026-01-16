defmodule Jarga.Notifications.Application.UseCases.GetUnreadCount do
  @moduledoc """
  Gets the count of unread notifications for a user.
  """

  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Returns the number of unread notifications for a user.

  ## Examples

      iex> execute(user_id)
      5
  """
  def execute(user_id) do
    NotificationRepository.count_unread_by_user(user_id)
  end
end
