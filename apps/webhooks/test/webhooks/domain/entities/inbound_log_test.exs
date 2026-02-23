defmodule Webhooks.Domain.Entities.InboundLogTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Entities.InboundLog

  describe "new/1" do
    test "creates an inbound log struct with all fields" do
      attrs = %{
        id: "log-123",
        workspace_id: "ws-123",
        event_type: "payment.received",
        payload: %{"amount" => 100},
        source_ip: "192.168.1.1",
        signature_valid: true,
        handler_result: "ok",
        received_at: ~U[2026-01-01 00:00:00Z],
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      }

      log = InboundLog.new(attrs)

      assert log.id == "log-123"
      assert log.workspace_id == "ws-123"
      assert log.event_type == "payment.received"
      assert log.payload == %{"amount" => 100}
      assert log.source_ip == "192.168.1.1"
      assert log.signature_valid == true
      assert log.handler_result == "ok"
      assert log.received_at == ~U[2026-01-01 00:00:00Z]
    end

    test "defaults signature_valid to false" do
      log = InboundLog.new(%{})

      assert log.signature_valid == false
    end
  end

  describe "from_schema/1" do
    test "converts a map to a domain entity" do
      schema = %{
        id: "log-456",
        workspace_id: "ws-456",
        event_type: "order.shipped",
        payload: %{"order_id" => "ord-1"},
        source_ip: "10.0.0.1",
        signature_valid: false,
        handler_result: "error",
        received_at: ~U[2026-02-01 12:00:00Z],
        inserted_at: ~U[2026-02-01 12:00:00Z],
        updated_at: ~U[2026-02-01 12:00:00Z]
      }

      log = InboundLog.from_schema(schema)

      assert %InboundLog{} = log
      assert log.id == "log-456"
      assert log.workspace_id == "ws-456"
      assert log.event_type == "order.shipped"
      assert log.signature_valid == false
      assert log.handler_result == "error"
    end
  end
end
