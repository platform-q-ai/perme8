defmodule Jarga.Webhooks.Application.UseCases.UpdateWebhookSubscriptionTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.UpdateWebhookSubscription
  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription
  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionUpdated
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
    test "admin updates subscription URL", ctx do
      existing = %WebhookSubscription{
        id: "sub-1",
        url: "https://old.com/hook",
        workspace_id: "ws-123"
      }

      updated = %WebhookSubscription{
        id: "sub-1",
        url: "https://new.com/hook",
        workspace_id: "ws-123"
      }

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> existing end)
      |> expect(:update, fn ^existing, %{url: "https://new.com/hook"}, _opts -> {:ok, updated} end)

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        subscription_id: "sub-1",
        attrs: %{url: "https://new.com/hook"}
      }

      assert {:ok, result} = UpdateWebhookSubscription.execute(params, base_opts(ctx))
      assert result.url == "https://new.com/hook"

      events = TestEventBus.get_events(name: ctx.event_bus_name)
      assert [%WebhookSubscriptionUpdated{}] = events
    end

    test "admin deactivates subscription", ctx do
      existing = %WebhookSubscription{id: "sub-1", is_active: true, workspace_id: "ws-123"}
      updated = %WebhookSubscription{id: "sub-1", is_active: false, workspace_id: "ws-123"}

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> existing end)
      |> expect(:update, fn ^existing, %{is_active: false}, _opts -> {:ok, updated} end)

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        subscription_id: "sub-1",
        attrs: %{is_active: false}
      }

      assert {:ok, result} = UpdateWebhookSubscription.execute(params, base_opts(ctx))
      assert result.is_active == false
    end

    test "not found returns error", ctx do
      MockWebhookRepository
      |> expect(:get, fn "sub-999", _opts -> nil end)

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        subscription_id: "sub-999",
        attrs: %{url: "https://new.com"}
      }

      assert {:error, :not_found} = UpdateWebhookSubscription.execute(params, base_opts(ctx))
    end

    test "non-admin returns forbidden", ctx do
      opts =
        Keyword.merge(base_opts(ctx),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        subscription_id: "sub-1",
        attrs: %{url: "https://new.com"}
      }

      assert {:error, :forbidden} = UpdateWebhookSubscription.execute(params, opts)
    end
  end
end
