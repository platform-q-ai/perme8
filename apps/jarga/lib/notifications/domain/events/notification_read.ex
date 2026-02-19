defmodule Jarga.Notifications.Domain.Events.NotificationRead do
  @moduledoc """
  Domain event emitted when a notification is marked as read.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "notification",
    fields: [notification_id: nil, user_id: nil],
    required: [:notification_id, :user_id]
end
