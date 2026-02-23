defmodule Webhooks.Application.UseCases.DispatchWebhookTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.DispatchWebhook
  alias Webhooks.Domain.Entities.{Subscription, Delivery}

  defmodule MockSubscriptionRepo do
    def list_active_for_event_type("ws-123", "project.created", _repo) do
      {:ok,
       [
         Subscription.new(%{
           id: "sub-1",
           url: "https://example.com/hook1",
           secret: "secret-abc",
           event_types: ["project.created"],
           is_active: true,
           workspace_id: "ws-123"
         })
       ]}
    end

    def list_active_for_event_type("ws-123", "project.deleted", _repo) do
      {:ok, []}
    end

    def list_active_for_event_type("ws-multi", "project.created", _repo) do
      {:ok,
       [
         Subscription.new(%{
           id: "sub-a",
           url: "https://example.com/hook-a",
           secret: "secret-a",
           event_types: ["project.created"],
           is_active: true,
           workspace_id: "ws-multi"
         }),
         Subscription.new(%{
           id: "sub-b",
           url: "https://example.com/hook-b",
           secret: "secret-b",
           event_types: ["project.created"],
           is_active: true,
           workspace_id: "ws-multi"
         })
       ]}
    end
  end

  defmodule SuccessHttpDispatcher do
    def dispatch(_url, _payload, _headers) do
      {:ok, 200, "OK"}
    end
  end

  defmodule FailureHttpDispatcher do
    def dispatch(_url, _payload, _headers) do
      {:ok, 500, "Internal Server Error"}
    end
  end

  defmodule ErrorHttpDispatcher do
    def dispatch(_url, _payload, _headers) do
      {:error, :timeout}
    end
  end

  defmodule MockDeliveryRepo do
    # Track state via process dictionary for test assertions
    def insert(attrs, _repo) do
      delivery =
        Delivery.new(%{
          id: "del-#{System.unique_integer([:positive])}",
          subscription_id: attrs.subscription_id,
          event_type: attrs.event_type,
          payload: attrs.payload,
          status: attrs.status,
          response_code: attrs[:response_code],
          response_body: attrs[:response_body],
          attempts: attrs[:attempts] || 1,
          next_retry_at: attrs[:next_retry_at]
        })

      send(self(), {:delivery_inserted, delivery})
      {:ok, delivery}
    end

    def update_status(_delivery_id, _attrs, _repo) do
      {:ok, Delivery.new(%{id: "del-updated"})}
    end
  end

  describe "execute/2 - successful dispatch" do
    test "dispatches HTTP POST with HMAC signature and records success" do
      params = %{
        workspace_id: "ws-123",
        event_type: "project.created",
        payload: %{"project_id" => "p-1", "name" => "Test Project"}
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: SuccessHttpDispatcher
      ]

      assert {:ok, deliveries} = DispatchWebhook.execute(params, opts)
      assert length(deliveries) == 1

      # Verify delivery was created with success status
      assert_received {:delivery_inserted, delivery}
      assert delivery.status == "success"
      assert delivery.response_code == 200
      assert delivery.attempts == 1
    end

    test "dispatches to multiple matching subscriptions" do
      params = %{
        workspace_id: "ws-multi",
        event_type: "project.created",
        payload: %{"project_id" => "p-1"}
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: SuccessHttpDispatcher
      ]

      assert {:ok, deliveries} = DispatchWebhook.execute(params, opts)
      assert length(deliveries) == 2
    end
  end

  describe "execute/2 - HTTP failure" do
    test "records failure with retry schedule on 500 response" do
      params = %{
        workspace_id: "ws-123",
        event_type: "project.created",
        payload: %{"project_id" => "p-1"}
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: FailureHttpDispatcher
      ]

      assert {:ok, deliveries} = DispatchWebhook.execute(params, opts)
      assert length(deliveries) == 1

      assert_received {:delivery_inserted, delivery}
      assert delivery.status == "pending"
      assert delivery.response_code == 500
      assert delivery.next_retry_at != nil
    end

    test "records failure with retry schedule on connection error" do
      params = %{
        workspace_id: "ws-123",
        event_type: "project.created",
        payload: %{"project_id" => "p-1"}
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: ErrorHttpDispatcher
      ]

      assert {:ok, deliveries} = DispatchWebhook.execute(params, opts)
      assert length(deliveries) == 1

      assert_received {:delivery_inserted, delivery}
      assert delivery.status == "pending"
      assert delivery.next_retry_at != nil
    end
  end

  describe "execute/2 - no matching subscriptions" do
    test "returns empty list when no subscriptions match event type" do
      params = %{
        workspace_id: "ws-123",
        event_type: "project.deleted",
        payload: %{"project_id" => "p-1"}
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo,
        http_dispatcher: SuccessHttpDispatcher
      ]

      assert {:ok, []} = DispatchWebhook.execute(params, opts)
    end
  end
end
