defmodule Jarga.Webhooks.Application.UseCases.CreateWebhookSubscriptionTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.CreateWebhookSubscription
  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription
  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionCreated
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

  describe "execute/2 - successful creation" do
    test "admin creates subscription and emits event", ctx do
      subscription = %WebhookSubscription{
        id: Ecto.UUID.generate(),
        url: "https://example.com/hook",
        event_types: ["projects.project_created"],
        is_active: true,
        workspace_id: "ws-123"
      }

      MockWebhookRepository
      |> expect(:insert, fn attrs, _opts ->
        assert attrs.url == "https://example.com/hook"
        assert attrs.event_types == ["projects.project_created"]
        assert is_binary(attrs.secret)
        assert String.length(attrs.secret) >= 32
        {:ok, subscription}
      end)

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        attrs: %{
          url: "https://example.com/hook",
          event_types: ["projects.project_created"]
        }
      }

      assert {:ok, result} = CreateWebhookSubscription.execute(params, base_opts(ctx))
      assert result.url == "https://example.com/hook"

      events = TestEventBus.get_events(name: ctx.event_bus_name)
      assert [%WebhookSubscriptionCreated{} = event] = events
      assert event.aggregate_id == subscription.id
      assert event.workspace_id == "ws-123"
    end

    test "auto-generates signing secret of 32+ chars", ctx do
      MockWebhookRepository
      |> expect(:insert, fn attrs, _opts ->
        assert is_binary(attrs.secret)
        assert String.length(attrs.secret) >= 32
        {:ok, %WebhookSubscription{id: Ecto.UUID.generate()}}
      end)

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        attrs: %{url: "https://example.com/hook"}
      }

      assert {:ok, _} = CreateWebhookSubscription.execute(params, base_opts(ctx))
    end
  end

  describe "execute/2 - authorization failures" do
    test "rejects non-admin role", ctx do
      opts =
        Keyword.merge(base_opts(ctx),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        attrs: %{url: "https://example.com/hook"}
      }

      assert {:error, :forbidden} = CreateWebhookSubscription.execute(params, opts)
    end

    test "rejects non-member", ctx do
      opts =
        Keyword.merge(base_opts(ctx),
          membership_checker: fn _actor, _workspace_id -> {:error, :unauthorized} end
        )

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        attrs: %{url: "https://example.com/hook"}
      }

      assert {:error, :unauthorized} = CreateWebhookSubscription.execute(params, opts)
    end
  end

  describe "execute/2 - repository failures" do
    test "changeset errors bubble up", ctx do
      MockWebhookRepository
      |> expect(:insert, fn _attrs, _opts ->
        changeset = %Ecto.Changeset{
          valid?: false,
          errors: [url: {"can't be blank", [validation: :required]}]
        }

        {:error, changeset}
      end)

      params = %{
        actor: %{id: "user-1"},
        workspace_id: "ws-123",
        attrs: %{url: ""}
      }

      assert {:error, %Ecto.Changeset{}} =
               CreateWebhookSubscription.execute(params, base_opts(ctx))

      # No event should be emitted on failure
      assert [] = TestEventBus.get_events(name: ctx.event_bus_name)
    end
  end
end
