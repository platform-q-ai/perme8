defmodule Jarga.Webhooks.Domain.Entities.WebhookDeliveryTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Entities.WebhookDelivery

  describe "new/1" do
    test "creates struct from attrs map" do
      attrs = %{
        id: "del-123",
        webhook_subscription_id: "sub-456",
        event_type: "projects.project_created",
        payload: %{"data" => "test"},
        status: "success",
        response_code: 200,
        response_body: "OK",
        attempts: 1,
        max_attempts: 5
      }

      delivery = WebhookDelivery.new(attrs)

      assert delivery.id == "del-123"
      assert delivery.webhook_subscription_id == "sub-456"
      assert delivery.event_type == "projects.project_created"
      assert delivery.payload == %{"data" => "test"}
      assert delivery.status == "success"
      assert delivery.response_code == 200
      assert delivery.response_body == "OK"
      assert delivery.attempts == 1
      assert delivery.max_attempts == 5
    end

    test "applies default values" do
      delivery = WebhookDelivery.new(%{})

      assert delivery.status == "pending"
      assert delivery.attempts == 0
      assert delivery.max_attempts == 5
    end

    test "has all expected fields" do
      delivery = WebhookDelivery.new(%{})

      assert Map.has_key?(delivery, :id)
      assert Map.has_key?(delivery, :webhook_subscription_id)
      assert Map.has_key?(delivery, :event_type)
      assert Map.has_key?(delivery, :payload)
      assert Map.has_key?(delivery, :status)
      assert Map.has_key?(delivery, :response_code)
      assert Map.has_key?(delivery, :response_body)
      assert Map.has_key?(delivery, :attempts)
      assert Map.has_key?(delivery, :max_attempts)
      assert Map.has_key?(delivery, :next_retry_at)
      assert Map.has_key?(delivery, :inserted_at)
      assert Map.has_key?(delivery, :updated_at)
    end

    test "status values are valid strings" do
      for status <- ["pending", "success", "failed"] do
        delivery = WebhookDelivery.new(%{status: status})
        assert delivery.status == status
      end
    end
  end

  describe "from_map/1" do
    test "is an alias for new/1" do
      attrs = %{event_type: "test.event", status: "failed"}

      assert WebhookDelivery.from_map(attrs) == WebhookDelivery.new(attrs)
    end
  end
end
