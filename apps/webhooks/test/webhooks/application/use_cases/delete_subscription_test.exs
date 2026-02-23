defmodule Webhooks.Application.UseCases.DeleteSubscriptionTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.DeleteSubscription
  alias Webhooks.Domain.Entities.Subscription

  defmodule MockSubscriptionRepo do
    def delete("sub-123", _repo) do
      {:ok,
       Subscription.new(%{
         id: "sub-123",
         url: "https://example.com/hook",
         secret: "supersecret",
         event_types: ["project.created"],
         workspace_id: "ws-123"
       })}
    end

    def delete("sub-missing", _repo) do
      {:error, :not_found}
    end
  end

  describe "execute/2 - successful deletion" do
    test "deletes subscription and returns it" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-123"
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, %Subscription{} = subscription} = DeleteSubscription.execute(params, opts)
      assert subscription.id == "sub-123"
    end
  end

  describe "execute/2 - not found" do
    test "returns not_found for missing subscription" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-missing"
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :not_found} = DeleteSubscription.execute(params, opts)
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden for non-admin roles" do
      params = %{
        workspace_id: "ws-123",
        member_role: :member,
        subscription_id: "sub-123"
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = DeleteSubscription.execute(params, opts)
    end

    test "returns forbidden for guest role" do
      params = %{
        workspace_id: "ws-123",
        member_role: :guest,
        subscription_id: "sub-123"
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = DeleteSubscription.execute(params, opts)
    end
  end
end
