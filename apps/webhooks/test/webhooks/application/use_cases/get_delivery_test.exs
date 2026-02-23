defmodule Webhooks.Application.UseCases.GetDeliveryTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.GetDelivery
  alias Webhooks.Domain.Entities.Delivery

  defmodule MockDeliveryRepo do
    def get_by_id("del-123", "ws-123", _repo) do
      {:ok,
       Delivery.new(%{
         id: "del-123",
         subscription_id: "sub-123",
         event_type: "project.created",
         payload: %{"project_id" => "p-1"},
         status: "success",
         response_code: 200,
         attempts: 1,
         next_retry_at: nil
       })}
    end

    def get_by_id("del-missing", _ws_id, _repo), do: {:error, :not_found}
  end

  describe "execute/2 - successful get" do
    test "returns delivery by ID with full details" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        delivery_id: "del-123"
      }

      opts = [delivery_repository: MockDeliveryRepo]

      assert {:ok, %Delivery{} = delivery} = GetDelivery.execute(params, opts)
      assert delivery.id == "del-123"
      assert delivery.event_type == "project.created"
      assert delivery.payload == %{"project_id" => "p-1"}
      assert delivery.status == "success"
      assert delivery.response_code == 200
      assert delivery.attempts == 1
    end
  end

  describe "execute/2 - not found" do
    test "returns not_found for missing delivery" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        delivery_id: "del-missing"
      }

      opts = [delivery_repository: MockDeliveryRepo]

      assert {:error, :not_found} = GetDelivery.execute(params, opts)
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden for non-admin roles" do
      params = %{
        workspace_id: "ws-123",
        member_role: :member,
        delivery_id: "del-123"
      }

      opts = [delivery_repository: MockDeliveryRepo]

      assert {:error, :forbidden} = GetDelivery.execute(params, opts)
    end

    test "returns forbidden for guest role" do
      params = %{
        workspace_id: "ws-123",
        member_role: :guest,
        delivery_id: "del-123"
      }

      opts = [delivery_repository: MockDeliveryRepo]

      assert {:error, :forbidden} = GetDelivery.execute(params, opts)
    end
  end
end
