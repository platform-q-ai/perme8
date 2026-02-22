defmodule Jarga.Webhooks.Domain.Events.WebhookSubscriptionDeletedTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionDeleted

  describe "new/1" do
    test "creates event" do
      event =
        WebhookSubscriptionDeleted.new(%{
          aggregate_id: "sub-123",
          actor_id: "user-456",
          workspace_id: "ws-789"
        })

      assert event.event_type == "webhooks.webhook_subscription_deleted"
      assert event.aggregate_type == "webhook_subscription"
    end
  end
end
