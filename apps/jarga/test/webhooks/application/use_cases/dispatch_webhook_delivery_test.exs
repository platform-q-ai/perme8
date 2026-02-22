defmodule Jarga.Webhooks.Application.UseCases.DispatchWebhookDeliveryTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.DispatchWebhookDelivery
  alias Jarga.Webhooks.Domain.Entities.{WebhookSubscription, WebhookDelivery}
  alias Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted
  alias Jarga.Webhooks.Mocks.{MockHttpClient, MockDeliveryRepository}
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    test_name = :"test_event_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: test_name)
    {:ok, event_bus_name: test_name}
  end

  defp base_opts(ctx) do
    [
      http_client: MockHttpClient,
      delivery_repository: MockDeliveryRepository,
      event_bus: TestEventBus,
      event_bus_opts: [name: ctx.event_bus_name]
    ]
  end

  defp subscription do
    %WebhookSubscription{
      id: "sub-1",
      url: "https://example.com/hook",
      secret: "whsec_test_secret",
      event_types: ["projects.project_created"],
      is_active: true,
      workspace_id: "ws-123"
    }
  end

  describe "execute/2 - successful delivery" do
    test "sends signed HTTP POST and records success", ctx do
      delivery = %WebhookDelivery{
        id: "del-1",
        webhook_subscription_id: "sub-1",
        status: "success",
        response_code: 200,
        attempts: 1
      }

      MockHttpClient
      |> expect(:post, fn url, _payload, headers ->
        assert url == "https://example.com/hook"
        sig_header = Keyword.get(headers, :headers, %{}) |> Map.get("X-Webhook-Signature")
        assert sig_header != nil
        assert String.starts_with?(sig_header, "sha256=")
        {:ok, %{status: 200, body: "OK"}}
      end)

      MockDeliveryRepository
      |> expect(:insert, fn attrs, _opts ->
        assert attrs.status == "success"
        assert attrs.response_code == 200
        assert attrs.attempts == 1
        {:ok, delivery}
      end)

      params = %{
        subscription: subscription(),
        event_type: "projects.project_created",
        payload: %{"project_id" => "proj-1"}
      }

      assert {:ok, result} = DispatchWebhookDelivery.execute(params, base_opts(ctx))
      assert result.status == "success"

      events = TestEventBus.get_events(name: ctx.event_bus_name)
      assert [%WebhookDeliveryCompleted{status: "success"}] = events
    end
  end

  describe "execute/2 - HTTP failure" do
    test "records pending with retry info on 4xx/5xx", ctx do
      delivery = %WebhookDelivery{
        id: "del-1",
        status: "pending",
        attempts: 1,
        next_retry_at: ~U[2026-01-01 12:01:00Z]
      }

      MockHttpClient
      |> expect(:post, fn _url, _payload, _headers ->
        {:ok, %{status: 500, body: "Internal Server Error"}}
      end)

      MockDeliveryRepository
      |> expect(:insert, fn attrs, _opts ->
        assert attrs.status == "pending"
        assert attrs.attempts == 1
        assert attrs.next_retry_at != nil
        {:ok, delivery}
      end)

      params = %{
        subscription: subscription(),
        event_type: "projects.project_created",
        payload: %{"project_id" => "proj-1"}
      }

      assert {:ok, result} = DispatchWebhookDelivery.execute(params, base_opts(ctx))
      assert result.status == "pending"
    end

    test "records pending on connection error", ctx do
      delivery = %WebhookDelivery{id: "del-1", status: "pending", attempts: 1}

      MockHttpClient
      |> expect(:post, fn _url, _payload, _headers ->
        {:error, :econnrefused}
      end)

      MockDeliveryRepository
      |> expect(:insert, fn attrs, _opts ->
        assert attrs.status == "pending"
        assert attrs.attempts == 1
        {:ok, delivery}
      end)

      params = %{
        subscription: subscription(),
        event_type: "projects.project_created",
        payload: %{"project_id" => "proj-1"}
      }

      assert {:ok, _} = DispatchWebhookDelivery.execute(params, base_opts(ctx))
    end
  end

  describe "execute/2 - max retries" do
    test "marks as failed when max retries exhausted on first attempt with max=1", ctx do
      sub = %{subscription() | id: "sub-max"}
      delivery = %WebhookDelivery{id: "del-1", status: "failed", attempts: 1}

      MockHttpClient
      |> expect(:post, fn _url, _payload, _headers ->
        {:ok, %{status: 500, body: "fail"}}
      end)

      MockDeliveryRepository
      |> expect(:insert, fn attrs, _opts ->
        assert attrs.status == "failed"
        assert attrs.next_retry_at == nil
        {:ok, delivery}
      end)

      params = %{
        subscription: sub,
        event_type: "projects.project_created",
        payload: %{"data" => "test"},
        max_attempts: 1
      }

      assert {:ok, result} = DispatchWebhookDelivery.execute(params, base_opts(ctx))
      assert result.status == "failed"
    end
  end

  describe "execute/2 - inactive subscription" do
    test "skips inactive subscriptions", ctx do
      inactive_sub = %{subscription() | is_active: false}

      params = %{
        subscription: inactive_sub,
        event_type: "projects.project_created",
        payload: %{"data" => "test"}
      }

      assert {:error, :subscription_inactive} =
               DispatchWebhookDelivery.execute(params, base_opts(ctx))
    end
  end
end
