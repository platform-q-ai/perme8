defmodule Webhooks.Application.UseCases.RetryDeliveryTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.RetryDelivery
  alias Webhooks.Domain.Entities.{Delivery, Subscription}

  defmodule MockSubscriptionRepo do
    def get_by_id("sub-123", _ws, _repo) do
      {:ok,
       Subscription.new(%{
         id: "sub-123",
         url: "https://example.com/hook",
         secret: "secret-abc",
         event_types: ["project.created"],
         is_active: true,
         workspace_id: "ws-123"
       })}
    end
  end

  defmodule SuccessDispatcher do
    def dispatch(_url, _payload, _headers), do: {:ok, 200, "OK"}
  end

  defmodule FailureDispatcher do
    def dispatch(_url, _payload, _headers), do: {:ok, 500, "Server Error"}
  end

  defmodule MockDeliveryRepo do
    def update_status(delivery_id, attrs, _repo) do
      delivery =
        Delivery.new(%{
          id: delivery_id,
          subscription_id: attrs[:subscription_id] || "sub-123",
          event_type: attrs[:event_type] || "project.created",
          status: attrs.status,
          response_code: attrs[:response_code],
          attempts: attrs.attempts,
          next_retry_at: attrs[:next_retry_at]
        })

      send(self(), {:delivery_updated, delivery})
      {:ok, delivery}
    end
  end

  describe "execute/2 - successful retry" do
    test "on success: sets status to success, clears next_retry_at" do
      delivery = %Delivery{
        id: "del-1",
        subscription_id: "sub-123",
        event_type: "project.created",
        payload: %{"project_id" => "p-1"},
        status: "pending",
        attempts: 1,
        next_retry_at: ~U[2026-01-01 00:00:00Z]
      }

      params = %{delivery: delivery}

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: SuccessDispatcher
      ]

      assert {:ok, %Delivery{} = updated} = RetryDelivery.execute(params, opts)
      assert updated.status == "success"
      assert updated.attempts == 2

      assert_received {:delivery_updated, updated_delivery}
      assert updated_delivery.status == "success"
      assert updated_delivery.next_retry_at == nil
    end
  end

  describe "execute/2 - failed retry with retries remaining" do
    test "on failure: increments attempts and sets next_retry_at" do
      delivery = %Delivery{
        id: "del-1",
        subscription_id: "sub-123",
        event_type: "project.created",
        payload: %{"project_id" => "p-1"},
        status: "pending",
        attempts: 2,
        next_retry_at: ~U[2026-01-01 00:00:00Z]
      }

      params = %{delivery: delivery}

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: FailureDispatcher
      ]

      assert {:ok, %Delivery{} = updated} = RetryDelivery.execute(params, opts)
      assert updated.status == "pending"
      assert updated.attempts == 3

      assert_received {:delivery_updated, updated_delivery}
      assert updated_delivery.next_retry_at != nil
    end
  end

  describe "execute/2 - max retries reached" do
    test "on failure with max retries: sets status to failed, clears next_retry_at" do
      delivery = %Delivery{
        id: "del-1",
        subscription_id: "sub-123",
        event_type: "project.created",
        payload: %{"project_id" => "p-1"},
        status: "pending",
        attempts: 4,
        next_retry_at: ~U[2026-01-01 00:00:00Z]
      }

      params = %{delivery: delivery}

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: FailureDispatcher
      ]

      assert {:ok, %Delivery{} = updated} = RetryDelivery.execute(params, opts)
      assert updated.status == "failed"
      assert updated.attempts == 5

      assert_received {:delivery_updated, updated_delivery}
      assert updated_delivery.status == "failed"
      assert updated_delivery.next_retry_at == nil
    end
  end
end
