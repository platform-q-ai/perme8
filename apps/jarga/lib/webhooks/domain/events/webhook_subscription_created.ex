defmodule Jarga.Webhooks.Domain.Events.WebhookSubscriptionCreated do
  @moduledoc """
  Domain event emitted when a webhook subscription is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "webhook_subscription",
    fields: [url: nil, event_types: []],
    required: [:workspace_id]
end
