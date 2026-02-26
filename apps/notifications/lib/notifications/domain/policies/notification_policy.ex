defmodule Notifications.Domain.Policies.NotificationPolicy do
  @moduledoc """
  Pure business rules for notifications.

  All functions are pure — no I/O, no database access, no side effects.
  """

  alias Notifications.Domain.Entities.Notification

  @valid_types ["workspace_invitation"]

  @doc """
  Returns true when the notification belongs to the given user.
  """
  @spec belongs_to_user?(Notification.t(), String.t()) :: boolean()
  def belongs_to_user?(%Notification{user_id: user_id}, user_id), do: true
  def belongs_to_user?(%Notification{}, _user_id), do: false

  @doc """
  Returns true when the notification can be marked as read.

  A notification can be marked as read when it belongs to the user
  and is currently unread.
  """
  @spec can_mark_as_read?(Notification.t(), String.t()) :: boolean()
  def can_mark_as_read?(%Notification{} = notification, user_id) do
    belongs_to_user?(notification, user_id) and readable?(notification)
  end

  @doc """
  Returns true when the notification is unread.
  """
  @spec readable?(Notification.t()) :: boolean()
  def readable?(%Notification{read: false}), do: true
  def readable?(%Notification{}), do: false

  @doc """
  Returns true when the given notification type is valid.
  """
  @spec valid_type?(String.t() | nil) :: boolean()
  def valid_type?(type) when type in @valid_types, do: true
  def valid_type?(_type), do: false
end
