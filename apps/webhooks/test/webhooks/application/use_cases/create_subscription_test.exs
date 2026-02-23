defmodule Webhooks.Application.UseCases.CreateSubscriptionTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.CreateSubscription
  alias Webhooks.Domain.Entities.Subscription

  # In-memory test double for subscription repository
  defmodule MockSubscriptionRepo do
    def insert(attrs, _repo) do
      subscription =
        Subscription.new(%{
          id: "sub-123",
          url: attrs.url || attrs[:url],
          secret: attrs.secret || attrs[:secret],
          event_types: attrs.event_types || attrs[:event_types] || [],
          is_active: Map.get(attrs, :is_active, true),
          workspace_id: attrs.workspace_id || attrs[:workspace_id],
          created_by_id: attrs.created_by_id || attrs[:created_by_id],
          inserted_at: ~U[2026-01-01 00:00:00Z],
          updated_at: ~U[2026-01-01 00:00:00Z]
        })

      {:ok, subscription}
    end
  end

  defmodule FailingSubscriptionRepo do
    def insert(_attrs, _repo) do
      {:error, :invalid_changeset}
    end
  end

  describe "execute/2 - successful creation" do
    test "creates subscription with auto-generated secret" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        url: "https://example.com/webhook",
        event_types: ["project.created", "document.created"]
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, %Subscription{} = subscription} = CreateSubscription.execute(params, opts)
      assert subscription.url == "https://example.com/webhook"
      assert subscription.event_types == ["project.created", "document.created"]
      assert subscription.workspace_id == "ws-123"
    end

    test "returns subscription with secret included" do
      params = %{
        workspace_id: "ws-123",
        member_role: :owner,
        url: "https://example.com/webhook",
        event_types: ["project.created"]
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, %Subscription{} = subscription} = CreateSubscription.execute(params, opts)
      assert subscription.secret != nil
      assert is_binary(subscription.secret)
    end

    test "generated secret is at least 32 characters" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        url: "https://example.com/webhook",
        event_types: ["project.created"]
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, %Subscription{} = subscription} = CreateSubscription.execute(params, opts)
      assert String.length(subscription.secret) >= 32
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden when member role is :member" do
      params = %{
        workspace_id: "ws-123",
        member_role: :member,
        url: "https://example.com/webhook",
        event_types: ["project.created"]
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = CreateSubscription.execute(params, opts)
    end

    test "returns forbidden when member role is :guest" do
      params = %{
        workspace_id: "ws-123",
        member_role: :guest,
        url: "https://example.com/webhook",
        event_types: ["project.created"]
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = CreateSubscription.execute(params, opts)
    end
  end

  describe "execute/2 - repository failures" do
    test "returns error when repository insert fails" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        url: "https://example.com/webhook",
        event_types: ["project.created"]
      }

      opts = [subscription_repository: FailingSubscriptionRepo]

      assert {:error, :invalid_changeset} = CreateSubscription.execute(params, opts)
    end
  end
end
