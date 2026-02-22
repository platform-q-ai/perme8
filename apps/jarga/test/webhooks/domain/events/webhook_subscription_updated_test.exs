defmodule Jarga.Webhooks.Domain.Events.WebhookSubscriptionUpdatedTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionUpdated

  describe "new/1" do
    test "creates event with changes field" do
      event =
        WebhookSubscriptionUpdated.new(%{
          aggregate_id: "sub-123",
          actor_id: "user-456",
          workspace_id: "ws-789",
          changes: %{url: "https://new.example.com/hook"}
        })

      assert event.event_type == "webhooks.webhook_subscription_updated"
      assert event.aggregate_type == "webhook_subscription"
      assert event.changes == %{url: "https://new.example.com/hook"}
    end
  end
end
