defmodule Jarga.Webhooks.Application.UseCases.ListDeliveriesTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.ListDeliveries
  alias Jarga.Webhooks.Domain.Entities.WebhookDelivery
  alias Jarga.Webhooks.Mocks.MockDeliveryRepository

  setup :verify_on_exit!

  defp base_opts do
    [
      delivery_repository: MockDeliveryRepository,
      membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :admin}} end
    ]
  end

  describe "execute/2" do
    test "admin lists deliveries for a subscription" do
      deliveries = [
        %WebhookDelivery{id: "del-1", status: "success"},
        %WebhookDelivery{id: "del-2", status: "pending"}
      ]

      MockDeliveryRepository
      |> expect(:list_for_subscription, fn "sub-1", _opts -> deliveries end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-1"}

      assert {:ok, result} = ListDeliveries.execute(params, base_opts())
      assert length(result) == 2
    end

    test "non-admin returns forbidden" do
      opts =
        Keyword.merge(base_opts(),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-1"}

      assert {:error, :forbidden} = ListDeliveries.execute(params, opts)
    end
  end
end
