defmodule Jarga.Webhooks.Domain.Events.WebhookEventsTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionCreated
  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionUpdated
  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionDeleted
  alias Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted
  alias Jarga.Webhooks.Domain.Events.InboundWebhookReceived

  describe "WebhookSubscriptionCreated" do
    test "new/1 creates event with auto-generated fields" do
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

    test "derives correct event_type" do
      assert WebhookSubscriptionCreated.event_type() == "webhooks.webhook_subscription_created"
    end

    test "returns correct aggregate_type" do
      assert WebhookSubscriptionCreated.aggregate_type() == "webhook_subscription"
    end
  end

  describe "WebhookSubscriptionUpdated" do
    test "new/1 creates event with changes field" do
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

  describe "WebhookSubscriptionDeleted" do
    test "new/1 creates event" do
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

  describe "WebhookDeliveryCompleted" do
    test "new/1 creates event with delivery details" do
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

  describe "InboundWebhookReceived" do
    test "new/1 creates event with inbound details" do
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
