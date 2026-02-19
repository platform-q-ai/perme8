defmodule Jarga.Notifications.Domain do
  @moduledoc """
  Domain layer boundary for the Notifications context.

  Contains domain events for notification lifecycle:

  ## Events
  - `Events.NotificationCreated` - Notification created
  - `Events.NotificationRead` - Notification marked as read
  - `Events.NotificationActionTaken` - Action taken on notification

  ## Dependency Rule

  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases)
  - Infrastructure layer (repos, schemas, notifiers)
  - External libraries (Ecto, Phoenix, etc.)
  - Other contexts
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Events.NotificationCreated,
      Events.NotificationRead,
      Events.NotificationActionTaken
    ]
end
