defmodule Jarga.Webhooks.Domain.Events.InboundWebhookReceived do
  @moduledoc """
  Domain event emitted when an inbound webhook is received and processed.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "inbound_webhook",
    fields: [event_type_received: nil, signature_valid: nil, source_ip: nil],
    required: [:workspace_id]
end
