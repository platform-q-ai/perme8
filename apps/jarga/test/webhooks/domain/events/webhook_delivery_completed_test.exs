defmodule Jarga.Webhooks.Domain.Events.WebhookDeliveryCompletedTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted

  describe "new/1" do
    test "creates event with delivery details" do
      event =
        WebhookDeliveryCompleted.new(%{
          aggregate_id: "del-123",
          actor_id: "system",
          workspace_id: "ws-789",
          delivery_id: "del-123",
          status: "success",
          response_code: 200,
          attempts: 1
        })

      assert event.event_type == "webhooks.webhook_delivery_completed"
      assert event.aggregate_type == "webhook_delivery"
      assert event.delivery_id == "del-123"
      assert event.status == "success"
      assert event.response_code == 200
      assert event.attempts == 1
    end
  end
end
