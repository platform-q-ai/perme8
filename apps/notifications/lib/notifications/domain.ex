defmodule Notifications.Domain do
  @moduledoc """
  Domain boundary for the Notifications context.

  Contains pure business logic: entities, events, and policies.
  Has no external dependencies — all functions are pure.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Notification,
      Events.NotificationCreated,
      Events.NotificationRead,
      Policies.NotificationPolicy
    ]
end
