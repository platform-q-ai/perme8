defmodule Jarga.Notifications.Domain.Events.NotificationActionTaken do
  @moduledoc """
  Domain event emitted when a user takes action on a notification
  (e.g., accepts or declines a workspace invitation).
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "notification",
    fields: [notification_id: nil, user_id: nil, action: nil],
    required: [:notification_id, :user_id, :action]
end
