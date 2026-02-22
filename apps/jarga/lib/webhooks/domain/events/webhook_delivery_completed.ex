defmodule Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted do
  @moduledoc """
  Domain event emitted when a webhook delivery attempt completes (success or failure).
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "webhook_delivery",
    fields: [delivery_id: nil, status: nil, response_code: nil, attempts: nil],
    required: [:workspace_id]
end
