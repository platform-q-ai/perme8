defmodule Jarga.Notifications.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Notifications context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.NotificationSchema` - Ecto schema for notifications table

  ## Repositories (Data Access)
  - `Repositories.NotificationRepository` - Notification persistence operations

  ## Event Handlers (Subscribers)
  - `Subscribers.WorkspaceInvitationSubscriber` - Handles workspace invitation events (EventHandler)

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Application layer (to implement service behaviours)
  - Shared infrastructure (Repo)

  It can use external libraries (Ecto, Phoenix.PubSub, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Notifications.Application,
      Jarga.Notifications.Domain,
      Jarga.Repo,
      # Cross-context dependencies
      Identity,
      Identity.Repo,
      Jarga.Accounts,
      # EventHandler behaviour for subscriber conversion
      Perme8.Events
    ],
    exports: [
      Schemas.NotificationSchema,
      Repositories.NotificationRepository,
      Subscribers.WorkspaceInvitationSubscriber
    ]
end
