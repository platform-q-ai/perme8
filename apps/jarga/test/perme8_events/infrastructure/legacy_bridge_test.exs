defmodule Perme8.Events.Infrastructure.LegacyBridgeTest do
  use ExUnit.Case, async: true

  alias Perme8.Events.Infrastructure.LegacyBridge

  # Test event to verify catch-all behaviour
  defmodule UnknownEvent do
    use Perme8.Events.DomainEvent,
      aggregate_type: "unknown",
      fields: [data: nil],
      required: []
  end

  describe "translate/1" do
    test "unknown event returns empty list (catch-all)" do
      event =
        UnknownEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "user-1",
          data: "some-data"
        })

      assert [] = LegacyBridge.translate(event)
    end
  end

  describe "broadcast_legacy/1" do
    test "returns :ok for unknown events with no translations" do
      event =
        UnknownEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "user-1",
          data: "some-data"
        })

      # Should not crash and should return :ok
      assert :ok = LegacyBridge.broadcast_legacy(event)
    end
  end
end
