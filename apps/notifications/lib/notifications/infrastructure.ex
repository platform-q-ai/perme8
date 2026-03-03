defmodule Notifications.Infrastructure do
  @moduledoc """
  Infrastructure boundary for the Notifications context.

  Contains database schemas, repositories, queries, and event subscribers.
  Uses `Notifications.Repo` (NOT `Identity.Repo`) for all database operations.

  No dependency on `Jarga.Workspaces` — action handling has been removed
  from the Notifications bounded context.
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
      Subscribers.TaskCompletionSubscriber
    ]
end
