defmodule Jarga.Webhooks.Domain.Entities.WebhookSubscriptionTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription

  describe "new/1" do
    test "creates struct from attrs map" do
      attrs = %{
        id: "sub-123",
        url: "https://example.com/webhook",
        secret: "whsec_abc123",
        event_types: ["projects.project_created"],
        is_active: true,
        workspace_id: "ws-456",
        created_by_id: "user-789"
      }

      subscription = WebhookSubscription.new(attrs)

      assert subscription.id == "sub-123"
      assert subscription.url == "https://example.com/webhook"
      assert subscription.secret == "whsec_abc123"
      assert subscription.event_types == ["projects.project_created"]
      assert subscription.is_active == true
      assert subscription.workspace_id == "ws-456"
      assert subscription.created_by_id == "user-789"
    end

    test "applies default values" do
      subscription = WebhookSubscription.new(%{})

      assert subscription.is_active == true
      assert subscription.event_types == []
    end

    test "has all expected fields" do
      subscription = WebhookSubscription.new(%{})

      assert Map.has_key?(subscription, :id)
      assert Map.has_key?(subscription, :url)
      assert Map.has_key?(subscription, :secret)
      assert Map.has_key?(subscription, :event_types)
      assert Map.has_key?(subscription, :is_active)
      assert Map.has_key?(subscription, :workspace_id)
      assert Map.has_key?(subscription, :created_by_id)
      assert Map.has_key?(subscription, :inserted_at)
      assert Map.has_key?(subscription, :updated_at)
    end

    test "overrides defaults when provided" do
      subscription = WebhookSubscription.new(%{is_active: false, event_types: ["a.b"]})

      assert subscription.is_active == false
      assert subscription.event_types == ["a.b"]
    end
  end

  describe "from_map/1" do
    test "is an alias for new/1" do
      attrs = %{url: "https://example.com/hook", secret: "s3cret"}

      assert WebhookSubscription.from_map(attrs) == WebhookSubscription.new(attrs)
    end
  end
end
