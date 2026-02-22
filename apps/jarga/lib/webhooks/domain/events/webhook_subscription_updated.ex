defmodule Jarga.Webhooks.Domain.Events.WebhookSubscriptionUpdated do
  @moduledoc """
  Domain event emitted when a webhook subscription is updated.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "webhook_subscription",
    fields: [changes: %{}],
    required: [:workspace_id]
end
