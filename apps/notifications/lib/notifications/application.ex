defmodule Notifications.Application do
  @moduledoc """
  Application boundary for the Notifications context.

  Contains use cases that orchestrate domain logic and infrastructure.
  Defines the repository behaviour (port) for dependency injection.

  No dependency on Jarga.Workspaces — action handling has been
  removed from the Notifications bounded context.
  """

  use Boundary,
    top_level?: true,
    deps: [Notifications.Domain, Perme8.Events],
    exports: [
      UseCases.CreateNotification,
      UseCases.MarkAsRead,
      UseCases.MarkAllAsRead,
      UseCases.GetUnreadCount,
      UseCases.ListNotifications,
      UseCases.ListUnreadNotifications,
      Behaviours.NotificationRepositoryBehaviour
    ]
end
