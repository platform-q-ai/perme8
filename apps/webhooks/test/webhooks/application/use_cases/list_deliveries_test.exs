defmodule Webhooks.Application.UseCases.ListDeliveriesTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.ListDeliveries
  alias Webhooks.Domain.Entities.{Delivery, Subscription}

  defmodule MockSubscriptionRepo do
    def get_by_id("sub-123", "ws-123", _repo) do
      {:ok, Subscription.new(%{id: "sub-123", workspace_id: "ws-123"})}
    end

    def get_by_id("sub-missing", _ws_id, _repo), do: {:error, :not_found}
  end

  defmodule MockDeliveryRepo do
    def list_for_subscription("sub-123", _repo) do
      {:ok,
       [
         Delivery.new(%{
           id: "del-1",
           subscription_id: "sub-123",
           event_type: "project.created",
           status: "success",
           response_code: 200,
           attempts: 1
         }),
         Delivery.new(%{
           id: "del-2",
           subscription_id: "sub-123",
           event_type: "document.created",
           status: "pending",
           attempts: 0
         })
       ]}
    end

    def list_for_subscription("sub-empty", _repo), do: {:ok, []}
  end

  describe "execute/2 - successful listing" do
    test "returns list of deliveries for a subscription" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-123"
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo
      ]

      assert {:ok, deliveries} = ListDeliveries.execute(params, opts)
      assert length(deliveries) == 2
      assert Enum.all?(deliveries, fn d -> d.subscription_id == "sub-123" end)
    end

    test "returns empty list when no deliveries exist" do
      # For this test we need the subscription to exist but have no deliveries
      # We'll simulate by using a subscription that exists but has empty deliveries

      defmodule EmptySubRepo do
        def get_by_id("sub-empty", "ws-123", _repo) do
          {:ok, Subscription.new(%{id: "sub-empty", workspace_id: "ws-123"})}
        end
      end

      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-empty"
      }

      opts = [
        subscription_repository: EmptySubRepo,
        delivery_repository: MockDeliveryRepo
      ]

      assert {:ok, []} = ListDeliveries.execute(params, opts)
    end
  end

  describe "execute/2 - subscription not found" do
    test "returns not_found if subscription does not exist" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-missing"
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo
      ]

      assert {:error, :not_found} = ListDeliveries.execute(params, opts)
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden for non-admin roles" do
      params = %{
        workspace_id: "ws-123",
        member_role: :member,
        subscription_id: "sub-123"
      }

      opts = [
        subscription_repository: MockSubscriptionRepo,
        delivery_repository: MockDeliveryRepo
      ]

      assert {:error, :forbidden} = ListDeliveries.execute(params, opts)
    end
  end
end
