defmodule Jarga.Webhooks.Application.UseCases.DeleteWebhookSubscriptionTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.DeleteWebhookSubscription
  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription
  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionDeleted
  alias Jarga.Webhooks.Mocks.MockWebhookRepository
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    test_name = :"test_event_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: test_name)
    {:ok, event_bus_name: test_name}
  end

  defp base_opts(ctx) do
    [
      webhook_repository: MockWebhookRepository,
      event_bus: TestEventBus,
      event_bus_opts: [name: ctx.event_bus_name],
      membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :admin}} end
    ]
  end

  describe "execute/2" do
    test "admin deletes subscription", ctx do
      subscription = %WebhookSubscription{
        id: "sub-1",
        url: "https://example.com/hook",
        workspace_id: "ws-123"
      }

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> subscription end)
      |> expect(:delete, fn ^subscription, _opts -> {:ok, subscription} end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-1"}

      assert {:ok, result} = DeleteWebhookSubscription.execute(params, base_opts(ctx))
      assert result.id == "sub-1"

      events = TestEventBus.get_events(name: ctx.event_bus_name)
      assert [%WebhookSubscriptionDeleted{}] = events
    end

    test "not found returns error", ctx do
      MockWebhookRepository
      |> expect(:get, fn "sub-999", _opts -> nil end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-999"}

      assert {:error, :not_found} = DeleteWebhookSubscription.execute(params, base_opts(ctx))
    end

    test "non-admin returns forbidden", ctx do
      opts =
        Keyword.merge(base_opts(ctx),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-1"}

      assert {:error, :forbidden} = DeleteWebhookSubscription.execute(params, opts)
    end
  end
end
