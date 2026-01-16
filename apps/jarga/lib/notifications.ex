defmodule Jarga.Notifications do
  @moduledoc """
  The Notifications context.

  Provides functionality for creating, managing, and delivering notifications to users.
  Supports multiple notification types (workspace invitations, etc.) with extensible data.
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: Infrastructure schemas + Infrastructure.Subscribers (for integration tests)
  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Repo],
    exports: [
      {Infrastructure.Schemas.NotificationSchema, []},
      # Exported for @integration tests that need to start PubSub subscribers
      {Infrastructure.Subscribers.WorkspaceInvitationSubscriber, []}
    ]

  alias Jarga.Notifications.Application.UseCases
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository

  @doc """
  Gets a notification by ID for a specific user.

  ## Examples

      iex> get_notification(notification_id, user_id)
      %Notification{}

      iex> get_notification(invalid_id, user_id)
      nil
  """
  def get_notification(notification_id, user_id) do
    NotificationRepository.get_by_user(notification_id, user_id)
  end

  @doc """
  Creates a workspace invitation notification.

  ## Examples

      iex> create_workspace_invitation_notification(%{
      ...>   user_id: user_id,
      ...>   workspace_id: workspace_id,
      ...>   workspace_name: "Acme Corp",
      ...>   invited_by_name: "John Doe",
      ...>   role: "member"
      ...> })
      {:ok, %Notification{}}
  """
  def create_workspace_invitation_notification(params) do
    UseCases.CreateWorkspaceInvitationNotification.execute(params)
  end

  @doc """
  Lists unread notifications for a user.

  ## Examples

      iex> list_unread_notifications(user_id)
      [%Notification{}, ...]
  """
  def list_unread_notifications(user_id) do
    UseCases.ListUnreadNotifications.execute(user_id)
  end

  @doc """
  Lists all notifications for a user, ordered by most recent.

  ## Examples

      iex> list_notifications(user_id)
      [%Notification{}, ...]
  """
  def list_notifications(user_id, opts \\ []) do
    UseCases.ListNotifications.execute(user_id, opts)
  end

  @doc """
  Marks a notification as read.

  ## Examples

      iex> mark_as_read(notification_id, user_id)
      {:ok, %Notification{}}
  """
  def mark_as_read(notification_id, user_id) do
    UseCases.MarkAsRead.execute(notification_id, user_id)
  end

  @doc """
  Marks all notifications as read for a user.

  ## Examples

      iex> mark_all_as_read(user_id)
      {:ok, count}
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
  Accepts a workspace invitation from a notification.

  ## Examples

      iex> accept_workspace_invitation(notification_id, user_id)
      {:ok, workspace_member}
  """
  def accept_workspace_invitation(notification_id, user_id, opts \\ []) do
    UseCases.AcceptWorkspaceInvitation.execute(notification_id, user_id, opts)
  end

  @doc """
  Declines a workspace invitation from a notification.

  ## Examples

      iex> decline_workspace_invitation(notification_id, user_id)
      {:ok, %Notification{}}
  """
  def decline_workspace_invitation(notification_id, user_id, opts \\ []) do
    UseCases.DeclineWorkspaceInvitation.execute(notification_id, user_id, opts)
  end

  @doc """
  Updates a notification for test purposes only.

  This function bypasses normal business logic and directly updates
  notification fields in the database. It should ONLY be used in test
  fixtures to set up test data.

  ## Examples

      iex> update_for_test(notification, %{read: true, read_at: ~U[2024-01-01 12:00:00Z]})
      %Notification{}
  """
  def update_for_test(notification, changes) do
    notification
    |> Ecto.Changeset.change(changes)
    |> NotificationRepository.update!()
  end
end
