defmodule Notifications do
  @moduledoc """
  The Notifications public facade.

  Provides functionality for creating, managing, and delivering notifications to users.
  Supports multiple notification types (workspace invitations, etc.) with extensible data.

  This module is the public API for the Notifications bounded context.
  All external consumers should call functions on this module rather than
  reaching into internal layers directly.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Notifications.Domain,
      Notifications.Application,
      Notifications.OTPApp
    ],
    exports: [
      {Domain.Entities.Notification, []},
      {Domain.Events.NotificationCreated, []},
      {Domain.Events.NotificationRead, []}
    ]

  alias Notifications.Application.UseCases

  @doc """
  Creates a notification.

  ## Parameters
    * `:user_id` - The ID of the user receiving the notification
    * `:type` - The notification type (e.g., "workspace_invitation")
    * `:title` - Notification title
    * `:body` - Notification body
    * `:data` - Additional data map (optional)

  ## Examples

      iex> create_notification(%{user_id: id, type: "workspace_invitation", title: "Invite"})
      {:ok, %NotificationSchema{}}
  """
  def create_notification(params) do
    UseCases.CreateNotification.execute(params)
  end

  @doc """
  Creates a workspace invitation notification.

  Convenience function that wraps `create_notification/1` with
  workspace_invitation-specific params. Auto-builds title and body
  from the provided data fields.

  ## Parameters
    * `:user_id` - The ID of the user receiving the notification
    * `:workspace_id` - The workspace ID
    * `:workspace_name` - The workspace name
    * `:invited_by_name` - Name of the person who sent the invitation
    * `:role` - The role being offered

  ## Examples

      iex> create_workspace_invitation_notification(%{
      ...>   user_id: user_id,
      ...>   workspace_id: workspace_id,
      ...>   workspace_name: "Acme Corp",
      ...>   invited_by_name: "John Doe",
      ...>   role: "member"
      ...> })
      {:ok, %NotificationSchema{}}
  """
  def create_workspace_invitation_notification(params) do
    create_notification(%{
      user_id: params[:user_id] || params["user_id"],
      type: "workspace_invitation",
      data: %{
        "workspace_id" => params[:workspace_id] || params["workspace_id"],
        "workspace_name" => params[:workspace_name] || params["workspace_name"],
        "invited_by_name" => params[:invited_by_name] || params["invited_by_name"],
        "role" => params[:role] || params["role"]
      }
    })
  end

  @doc """
  Gets a notification by ID for a specific user.

  Returns the notification if it belongs to the user, nil otherwise.

  ## Examples

      iex> get_notification(notification_id, user_id)
      %NotificationSchema{}

      iex> get_notification(invalid_id, user_id)
      nil
  """
  def get_notification(notification_id, user_id) do
    UseCases.GetNotification.execute(notification_id, user_id)
  end

  @doc """
  Lists all notifications for a user, ordered by most recent.

  ## Options
    * `:limit` - Maximum number of notifications to return

  ## Examples

      iex> list_notifications(user_id)
      [%NotificationSchema{}, ...]

      iex> list_notifications(user_id, limit: 20)
      [%NotificationSchema{}, ...]
  """
  def list_notifications(user_id, opts \\ []) do
    UseCases.ListNotifications.execute(user_id, opts)
  end

  @doc """
  Lists unread notifications for a user.

  ## Options
    * `:limit` - Maximum number of notifications to return

  ## Examples

      iex> list_unread_notifications(user_id)
      [%NotificationSchema{}, ...]

      iex> list_unread_notifications(user_id, limit: 20)
      [%NotificationSchema{}, ...]
  """
  def list_unread_notifications(user_id, opts \\ []) do
    UseCases.ListUnreadNotifications.execute(user_id, opts)
  end

  @doc """
  Marks a notification as read.

  Returns `{:ok, notification}` if successful.
  Returns `{:error, :not_found}` if notification doesn't exist or belongs to different user.

  ## Examples

      iex> mark_as_read(notification_id, user_id)
      {:ok, %NotificationSchema{}}
  """
  def mark_as_read(notification_id, user_id) do
    UseCases.MarkAsRead.execute(notification_id, user_id)
  end

  @doc """
  Marks all notifications as read for a user.

  Returns `{:ok, count}` where count is the number of notifications marked as read.

  ## Examples

      iex> mark_all_as_read(user_id)
      {:ok, 5}
  """
  def mark_all_as_read(user_id) do
    UseCases.MarkAllAsRead.execute(user_id)
  end

  @doc """
  Gets the count of unread notifications for a user.

  ## Examples

      iex> unread_count(user_id)
      5
  """
  def unread_count(user_id) do
    UseCases.GetUnreadCount.execute(user_id)
  end

  @doc """
  Ensures PubSub event subscribers are started.

  Used by consuming apps' test support modules (e.g. Jarga.DataCase)
  to start subscribers for integration tests where the Notifications
  OTP app has subscribers disabled in test mode.

  Returns the subscriber PID (either existing or newly started).
  """
  def ensure_subscribers_started do
    Notifications.OTPApp.ensure_subscribers_started()
  end
end
