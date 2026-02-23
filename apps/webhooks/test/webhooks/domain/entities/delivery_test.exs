defmodule Webhooks.Domain.Entities.DeliveryTest do
  use ExUnit.Case, async: true

  alias Webhooks.Domain.Entities.Delivery

  describe "new/1" do
    test "creates a delivery struct with all fields" do
      attrs = %{
        id: "del-123",
        subscription_id: "sub-123",
        event_type: "project.created",
        payload: %{"id" => "proj-1", "name" => "My Project"},
        status: "pending",
        response_code: nil,
        response_body: nil,
        attempts: 0,
        max_attempts: 5,
        next_retry_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00Z],
        updated_at: ~U[2026-01-01 00:00:00Z]
      }

      delivery = Delivery.new(attrs)

      assert delivery.id == "del-123"
      assert delivery.subscription_id == "sub-123"
      assert delivery.event_type == "project.created"
      assert delivery.payload == %{"id" => "proj-1", "name" => "My Project"}
      assert delivery.status == "pending"
      assert delivery.response_code == nil
      assert delivery.response_body == nil
      assert delivery.attempts == 0
      assert delivery.max_attempts == 5
      assert delivery.next_retry_at == nil
    end

    test "defaults status to pending" do
      delivery = Delivery.new(%{})

      assert delivery.status == "pending"
    end

    test "defaults attempts to 0" do
      delivery = Delivery.new(%{})

      assert delivery.attempts == 0
    end

    test "defaults max_attempts to 5" do
      delivery = Delivery.new(%{})

      assert delivery.max_attempts == 5
    end
  end

  describe "from_schema/1" do
    test "converts a map to a domain entity" do
      schema = %{
        id: "del-456",
        subscription_id: "sub-456",
        event_type: "document.created",
        payload: %{"title" => "Doc"},
        status: "success",
        response_code: 200,
        response_body: "OK",
        attempts: 1,
        max_attempts: 5,
        next_retry_at: nil,
        inserted_at: ~U[2026-02-01 00:00:00Z],
        updated_at: ~U[2026-02-01 00:00:00Z]
      }

      delivery = Delivery.from_schema(schema)

      assert %Delivery{} = delivery
      assert delivery.id == "del-456"
      assert delivery.subscription_id == "sub-456"
      assert delivery.status == "success"
      assert delivery.response_code == 200
    end
  end

  describe "success?/1" do
    test "returns true when status is success" do
      delivery = Delivery.new(%{status: "success"})
      assert Delivery.success?(delivery) == true
    end

    test "returns false when status is not success" do
      delivery = Delivery.new(%{status: "pending"})
      assert Delivery.success?(delivery) == false
    end
  end

  describe "failed?/1" do
    test "returns true when status is failed" do
      delivery = Delivery.new(%{status: "failed"})
      assert Delivery.failed?(delivery) == true
    end

    test "returns false when status is not failed" do
      delivery = Delivery.new(%{status: "pending"})
      assert Delivery.failed?(delivery) == false
    end
  end

  describe "pending?/1" do
    test "returns true when status is pending" do
      delivery = Delivery.new(%{status: "pending"})
      assert Delivery.pending?(delivery) == true
    end

    test "returns false when status is not pending" do
      delivery = Delivery.new(%{status: "success"})
      assert Delivery.pending?(delivery) == false
    end
  end

  describe "max_retries_reached?/1" do
    test "returns true when attempts >= max_attempts" do
      delivery = Delivery.new(%{attempts: 5, max_attempts: 5})
      assert Delivery.max_retries_reached?(delivery) == true
    end

    test "returns true when attempts exceed max_attempts" do
      delivery = Delivery.new(%{attempts: 6, max_attempts: 5})
      assert Delivery.max_retries_reached?(delivery) == true
    end

    test "returns false when attempts < max_attempts" do
      delivery = Delivery.new(%{attempts: 4, max_attempts: 5})
      assert Delivery.max_retries_reached?(delivery) == false
    end

    test "returns false when attempts is 0" do
      delivery = Delivery.new(%{attempts: 0})
      assert Delivery.max_retries_reached?(delivery) == false
    end
  end
end
