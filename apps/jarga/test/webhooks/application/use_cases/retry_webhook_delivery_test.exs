defmodule Jarga.Webhooks.Application.UseCases.RetryWebhookDeliveryTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.RetryWebhookDelivery
  alias Jarga.Webhooks.Domain.Entities.{WebhookSubscription, WebhookDelivery}
  alias Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted
  alias Jarga.Webhooks.Mocks.{MockHttpClient, MockDeliveryRepository, MockWebhookRepository}
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
      webhook_repository: MockWebhookRepository,
      event_bus: TestEventBus,
      event_bus_opts: [name: ctx.event_bus_name]
    ]
  end

  defp subscription do
    %WebhookSubscription{
      id: "sub-1",
      url: "https://example.com/hook",
      secret: "whsec_test_secret",
      is_active: true,
      workspace_id: "ws-123"
    }
  end

  defp pending_delivery do
    %WebhookDelivery{
      id: "del-1",
      webhook_subscription_id: "sub-1",
      event_type: "projects.project_created",
      payload: %{"project_id" => "proj-1"},
      status: "pending",
      attempts: 1,
      max_attempts: 5
    }
  end

  describe "execute/2 - retry success" do
    test "retries delivery and marks as success on 2xx", ctx do
      delivery = pending_delivery()

      MockDeliveryRepository
      |> expect(:get, fn "del-1", _opts -> delivery end)

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> subscription() end)

      MockHttpClient
      |> expect(:post, fn _url, _payload, _headers ->
        {:ok, %{status: 200, body: "OK"}}
      end)

      MockDeliveryRepository
      |> expect(:update, fn ^delivery, attrs, _opts ->
        assert attrs.status == "success"
        assert attrs.attempts == 2
        assert attrs.next_retry_at == nil
        {:ok, %{delivery | status: "success", attempts: 2}}
      end)

      params = %{delivery_id: "del-1"}

      assert {:ok, result} = RetryWebhookDelivery.execute(params, base_opts(ctx))
      assert result.status == "success"

      events = TestEventBus.get_events(name: ctx.event_bus_name)
      assert [%WebhookDeliveryCompleted{status: "success"}] = events
    end
  end

  describe "execute/2 - retry failure" do
    test "increments attempts with retry info on failure", ctx do
      delivery = pending_delivery()

      MockDeliveryRepository
      |> expect(:get, fn "del-1", _opts -> delivery end)

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> subscription() end)

      MockHttpClient
      |> expect(:post, fn _url, _payload, _headers ->
        {:ok, %{status: 500, body: "Error"}}
      end)

      MockDeliveryRepository
      |> expect(:update, fn ^delivery, attrs, _opts ->
        assert attrs.status == "pending"
        assert attrs.attempts == 2
        assert attrs.next_retry_at != nil
        {:ok, %{delivery | status: "pending", attempts: 2}}
      end)

      params = %{delivery_id: "del-1"}

      assert {:ok, result} = RetryWebhookDelivery.execute(params, base_opts(ctx))
      assert result.status == "pending"
    end

    test "marks as failed when retries exhausted", ctx do
      delivery = %{pending_delivery() | attempts: 4, max_attempts: 5}

      MockDeliveryRepository
      |> expect(:get, fn "del-1", _opts -> delivery end)

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> subscription() end)

      MockHttpClient
      |> expect(:post, fn _url, _payload, _headers ->
        {:ok, %{status: 500, body: "Error"}}
      end)

      MockDeliveryRepository
      |> expect(:update, fn ^delivery, attrs, _opts ->
        assert attrs.status == "failed"
        assert attrs.attempts == 5
        assert attrs.next_retry_at == nil
        {:ok, %{delivery | status: "failed", attempts: 5}}
      end)

      params = %{delivery_id: "del-1"}

      assert {:ok, result} = RetryWebhookDelivery.execute(params, base_opts(ctx))
      assert result.status == "failed"
    end
  end

  describe "execute/2 - already succeeded" do
    test "does not retry deliveries in success state", ctx do
      delivery = %{pending_delivery() | status: "success"}

      MockDeliveryRepository
      |> expect(:get, fn "del-1", _opts -> delivery end)

      params = %{delivery_id: "del-1"}

      assert {:error, :already_succeeded} = RetryWebhookDelivery.execute(params, base_opts(ctx))
    end
  end
end
