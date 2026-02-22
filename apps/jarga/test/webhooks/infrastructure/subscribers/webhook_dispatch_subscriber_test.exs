defmodule Jarga.Webhooks.Infrastructure.Subscribers.WebhookDispatchSubscriberTest do
  use Jarga.DataCase, async: false

  alias Jarga.Webhooks.Infrastructure.Subscribers.WebhookDispatchSubscriber

  describe "subscriptions/0" do
    test "subscribes to all context event topics" do
      topics = WebhookDispatchSubscriber.subscriptions()

      assert "events:identity" in topics
      assert "events:projects" in topics
      assert "events:documents" in topics
      assert "events:chat" in topics
      assert "events:notifications" in topics
      assert "events:agents" in topics
      assert "events:entity_relationship_manager" in topics
    end
  end

  describe "handle_event/1" do
    test "returns :ok for events without matching subscriptions" do
      # Create a dummy event with workspace_id
      event = %{
        __struct__: SomeFakeEvent,
        workspace_id: Ecto.UUID.generate(),
        event_type: "projects.project_created"
      }

      # No subscriptions in DB, should return :ok without error
      assert :ok = WebhookDispatchSubscriber.handle_event(event)
    end

    test "returns :ok for events without workspace_id" do
      event = %{__struct__: SomeFakeEvent, other_field: "value"}
      assert :ok = WebhookDispatchSubscriber.handle_event(event)
    end
  end
end
