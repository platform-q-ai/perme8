defmodule Jarga.Webhooks.Application.UseCases.GetDeliveryTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.GetDelivery
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
    test "admin gets delivery by ID" do
      delivery = %WebhookDelivery{id: "del-1", status: "success"}

      MockDeliveryRepository
      |> expect(:get, fn "del-1", _opts -> delivery end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", delivery_id: "del-1"}

      assert {:ok, result} = GetDelivery.execute(params, base_opts())
      assert result.id == "del-1"
    end

    test "not found returns error" do
      MockDeliveryRepository
      |> expect(:get, fn "del-999", _opts -> nil end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", delivery_id: "del-999"}

      assert {:error, :not_found} = GetDelivery.execute(params, base_opts())
    end

    test "non-admin returns forbidden" do
      opts =
        Keyword.merge(base_opts(),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", delivery_id: "del-1"}

      assert {:error, :forbidden} = GetDelivery.execute(params, opts)
    end
  end
end
