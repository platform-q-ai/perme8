defmodule Jarga.Notifications.Domain.Events.NotificationCreated do
  @moduledoc """
  Domain event emitted when a notification is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "notification",
    fields: [notification_id: nil, user_id: nil, type: nil, target_user_id: nil],
    required: [:notification_id, :user_id, :type]
end
