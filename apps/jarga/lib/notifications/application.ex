defmodule Jarga.Notifications.Application do
  @moduledoc """
  Application layer boundary for the Notifications context.

  Contains orchestration logic that coordinates infrastructure:

  ## Use Cases
  - `UseCases.AcceptWorkspaceInvitation` - Accept workspace invitation flow
  - `UseCases.CreateWorkspaceInvitationNotification` - Create invitation notification
  - `UseCases.DeclineWorkspaceInvitation` - Decline workspace invitation flow
  - `UseCases.GetUnreadCount` - Get unread notification count
  - `UseCases.ListNotifications` - List all notifications
  - `UseCases.ListUnreadNotifications` - List unread notifications
  - `UseCases.MarkAllAsRead` - Mark all notifications as read
  - `UseCases.MarkAsRead` - Mark single notification as read

  ## Dependency Rule

  The Application layer has no domain layer dependency (Notifications has no domain).

  It cannot import:
  - Infrastructure layer (repos, schemas, subscribers)
  - Other contexts directly (use dependency injection)
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Notifications.Domain, Jarga.Workspaces, Perme8.Events],
    exports: [
      UseCases.AcceptWorkspaceInvitation,
      UseCases.CreateWorkspaceInvitationNotification,
      UseCases.DeclineWorkspaceInvitation,
      UseCases.GetUnreadCount,
      UseCases.ListNotifications,
      UseCases.ListUnreadNotifications,
      UseCases.MarkAllAsRead,
      UseCases.MarkAsRead,
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.NotificationRepositoryBehaviour
    ]
end
