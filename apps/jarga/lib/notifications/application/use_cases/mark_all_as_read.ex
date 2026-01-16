defmodule Jarga.Notifications.Application.UseCases.MarkAllAsRead do
  @moduledoc """
  Marks all notifications as read for a user.
  """

  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Marks all unread notifications as read for a user.

  Returns `{:ok, count}` where count is the number of notifications marked as read.

  ## Examples

      iex> execute(user_id)
      {:ok, 5}
  """
  def execute(user_id) do
    NotificationRepository.mark_all_as_read(user_id)
  end
end
