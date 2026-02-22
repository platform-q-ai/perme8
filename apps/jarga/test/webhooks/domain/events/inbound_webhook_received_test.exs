defmodule Jarga.Webhooks.Domain.Events.InboundWebhookReceivedTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Events.InboundWebhookReceived

  describe "new/1" do
    test "creates event with inbound details" do
      event =
        InboundWebhookReceived.new(%{
          aggregate_id: "inb-123",
          actor_id: "system",
          workspace_id: "ws-789",
          event_type_received: "stripe.payment_succeeded",
          signature_valid: true,
          source_ip: "192.168.1.1"
        })

      assert event.event_type == "webhooks.inbound_webhook_received"
      assert event.aggregate_type == "inbound_webhook"
      assert event.event_type_received == "stripe.payment_succeeded"
      assert event.signature_valid == true
      assert event.source_ip == "192.168.1.1"
    end
  end
end
