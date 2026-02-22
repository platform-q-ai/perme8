defmodule Jarga.Webhooks.Domain.Entities.InboundWebhookTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Entities.InboundWebhook

  describe "new/1" do
    test "creates struct from attrs map" do
      now = DateTime.utc_now()

      attrs = %{
        id: "inb-123",
        workspace_id: "ws-456",
        event_type: "stripe.payment_succeeded",
        payload: %{"amount" => 1000},
        source_ip: "192.168.1.1",
        signature_valid: true,
        handler_result: "processed",
        received_at: now
      }

      inbound = InboundWebhook.new(attrs)

      assert inbound.id == "inb-123"
      assert inbound.workspace_id == "ws-456"
      assert inbound.event_type == "stripe.payment_succeeded"
      assert inbound.payload == %{"amount" => 1000}
      assert inbound.source_ip == "192.168.1.1"
      assert inbound.signature_valid == true
      assert inbound.handler_result == "processed"
      assert inbound.received_at == now
    end

    test "applies default values" do
      inbound = InboundWebhook.new(%{})

      assert inbound.signature_valid == false
    end

    test "has all expected fields" do
      inbound = InboundWebhook.new(%{})

      assert Map.has_key?(inbound, :id)
      assert Map.has_key?(inbound, :workspace_id)
      assert Map.has_key?(inbound, :event_type)
      assert Map.has_key?(inbound, :payload)
      assert Map.has_key?(inbound, :source_ip)
      assert Map.has_key?(inbound, :signature_valid)
      assert Map.has_key?(inbound, :handler_result)
      assert Map.has_key?(inbound, :received_at)
      assert Map.has_key?(inbound, :inserted_at)
    end
  end

  describe "from_map/1" do
    test "is an alias for new/1" do
      attrs = %{workspace_id: "ws-1", event_type: "test.event"}

      assert InboundWebhook.from_map(attrs) == InboundWebhook.new(attrs)
    end
  end
end
