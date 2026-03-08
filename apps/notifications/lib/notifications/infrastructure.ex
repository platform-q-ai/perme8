defmodule Notifications.Infrastructure do
  @moduledoc """
  Infrastructure boundary for the Notifications context.

  Contains database schemas, repositories, queries, and event subscribers.
  Uses `Notifications.Repo` (NOT `Identity.Repo`) for all database operations.

  Workspace operations are handled by `Identity` — no dependency needed here.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Notifications.Application,
      Notifications.Domain,
      Notifications.Repo,
      Identity,
      Perme8.Events
    ],
    exports: [
      Schemas.NotificationSchema,
      Repositories.NotificationRepository,
      Queries.NotificationQueries,
      Subscribers.WorkspaceInvitationSubscriber,
      Subscribers.TaskCompletionSubscriber,
      Subscribers.DomainEventNotificationRegistry,
      Subscribers.DomainEventNotificationSubscriber
    ]
end
