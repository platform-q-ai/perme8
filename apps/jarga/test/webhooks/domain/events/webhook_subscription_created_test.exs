defmodule Jarga.Webhooks.Domain.Events.WebhookSubscriptionCreatedTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionCreated

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event =
        WebhookSubscriptionCreated.new(%{
          aggregate_id: "sub-123",
          actor_id: "user-456",
          workspace_id: "ws-789",
          url: "https://example.com/hook",
          event_types: ["projects.project_created"]
        })

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "webhooks.webhook_subscription_created"
      assert event.aggregate_type == "webhook_subscription"
      assert event.aggregate_id == "sub-123"
      assert event.actor_id == "user-456"
      assert event.workspace_id == "ws-789"
      assert event.url == "https://example.com/hook"
      assert event.event_types == ["projects.project_created"]
    end
  end

  test "derives correct event_type" do
    assert WebhookSubscriptionCreated.event_type() == "webhooks.webhook_subscription_created"
  end

  test "returns correct aggregate_type" do
    assert WebhookSubscriptionCreated.aggregate_type() == "webhook_subscription"
  end
end
