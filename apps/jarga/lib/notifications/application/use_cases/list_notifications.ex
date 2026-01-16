defmodule Jarga.Notifications.Application.UseCases.ListNotifications do
  @moduledoc """
  Lists all notifications for a user.
  """

  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Lists notifications for a user, ordered by most recent.

  ## Options
    * `:limit` - Maximum number of notifications to return

  ## Examples

      iex> execute(user_id)
      [%Notification{}, ...]

      iex> execute(user_id, limit: 10)
      [%Notification{}, ...]
  """
  def execute(user_id, opts \\ []) do
    NotificationRepository.list_by_user(user_id, opts)
  end
end
