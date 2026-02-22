defmodule Jarga.Webhooks.Domain.Events.WebhookSubscriptionDeleted do
  @moduledoc """
  Domain event emitted when a webhook subscription is deleted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "webhook_subscription",
    fields: [],
    required: [:workspace_id]
end
