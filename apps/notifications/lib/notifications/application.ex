defmodule Notifications.Application do
  @moduledoc """
  Application boundary for the Notifications context.

  Contains use cases that orchestrate domain logic and infrastructure.
  Defines the repository behaviour (port) for dependency injection.

  Workspace operations are handled by `Identity` — no dependency needed here.
  """

  use Boundary,
    top_level?: true,
    deps: [Notifications.Domain, Perme8.Events],
    exports: [
      UseCases.CreateNotification,
      UseCases.GetNotification,
      UseCases.MarkAsRead,
      UseCases.MarkAllAsRead,
      UseCases.GetUnreadCount,
      UseCases.ListNotifications,
      UseCases.ListUnreadNotifications,
      Behaviours.NotificationRepositoryBehaviour
    ]
end
