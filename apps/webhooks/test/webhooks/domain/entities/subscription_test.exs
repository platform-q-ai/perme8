defmodule Webhooks.Domain.Entities.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Entities.Subscription

  describe "new/1" do
    test "creates a subscription struct with all fields" do
      attrs = %{
        id: "sub-123",
        url: "https://example.com/webhook",
        secret: "whsec_test_secret_value_here_1234567890",
        event_types: ["project.created", "document.created"],
        is_active: true,
        workspace_id: "ws-123",
        created_by_id: "user-123",
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      }

      subscription = Subscription.new(attrs)

      assert subscription.id == "sub-123"
      assert subscription.url == "https://example.com/webhook"
      assert subscription.secret == "whsec_test_secret_value_here_1234567890"
      assert subscription.event_types == ["project.created", "document.created"]
      assert subscription.is_active == true
      assert subscription.workspace_id == "ws-123"
      assert subscription.created_by_id == "user-123"
      assert subscription.inserted_at == ~U[2026-01-01 00:00:00Z]
      assert subscription.updated_at == ~U[2026-01-01 00:00:00Z]
    end

    test "defaults is_active to true when not provided" do
      attrs = %{
        id: "sub-123",
        url: "https://example.com/webhook",
        secret: "whsec_test_secret",
        event_types: [],
        workspace_id: "ws-123",
        created_by_id: "user-123"
      }

      subscription = Subscription.new(attrs)

      assert subscription.is_active == true
    end

    test "defaults event_types to empty list when not provided" do
      attrs = %{
        id: "sub-123",
        url: "https://example.com/webhook",
        secret: "whsec_test_secret",
        workspace_id: "ws-123",
        created_by_id: "user-123"
      }

      subscription = Subscription.new(attrs)

      assert subscription.event_types == []
    end
  end

  describe "from_schema/1" do
    test "converts a map to a domain entity" do
      schema = %{
        id: "sub-456",
        url: "https://example.com/hook",
        secret: "secret-value",
        event_types: ["project.updated"],
        is_active: false,
        workspace_id: "ws-456",
        created_by_id: "user-456",
        inserted_at: ~U[2026-02-01 12:00:00Z],
        updated_at: ~U[2026-02-01 12:00:00Z]
      }

      subscription = Subscription.from_schema(schema)

      assert %Subscription{} = subscription
      assert subscription.id == "sub-456"
      assert subscription.url == "https://example.com/hook"
      assert subscription.secret == "secret-value"
      assert subscription.event_types == ["project.updated"]
      assert subscription.is_active == false
      assert subscription.workspace_id == "ws-456"
      assert subscription.created_by_id == "user-456"
    end
  end

  describe "active?/1" do
    test "returns true when subscription is active" do
      subscription = Subscription.new(%{is_active: true})

      assert Subscription.active?(subscription) == true
    end

    test "returns false when subscription is not active" do
      subscription = Subscription.new(%{is_active: false})

      assert Subscription.active?(subscription) == false
    end
  end
end
