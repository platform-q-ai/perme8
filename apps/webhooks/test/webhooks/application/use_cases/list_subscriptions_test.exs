defmodule Webhooks.Application.UseCases.ListSubscriptionsTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.ListSubscriptions
  alias Webhooks.Domain.Entities.Subscription

  defmodule MockSubscriptionRepo do
    def list_for_workspace("ws-123", _repo) do
      {:ok,
       [
         Subscription.new(%{
           id: "sub-1",
           url: "https://example.com/hook1",
           secret: "supersecret1",
           event_types: ["project.created"],
           workspace_id: "ws-123"
         }),
         Subscription.new(%{
           id: "sub-2",
           url: "https://example.com/hook2",
           secret: "supersecret2",
           event_types: ["document.created"],
           workspace_id: "ws-123"
         })
       ]}
    end

    def list_for_workspace("ws-empty", _repo) do
      {:ok, []}
    end
  end

  describe "execute/2 - successful listing" do
    test "returns list of subscriptions without secrets" do
      params = %{workspace_id: "ws-123", member_role: :admin}
      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, subscriptions} = ListSubscriptions.execute(params, opts)
      assert length(subscriptions) == 2
      assert Enum.all?(subscriptions, fn s -> s.secret == nil end)
    end

    test "returns empty list when no subscriptions exist" do
      params = %{workspace_id: "ws-empty", member_role: :owner}
      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, []} = ListSubscriptions.execute(params, opts)
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden for non-admin roles" do
      params = %{workspace_id: "ws-123", member_role: :member}
      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = ListSubscriptions.execute(params, opts)
    end

    test "returns forbidden for guest role" do
      params = %{workspace_id: "ws-123", member_role: :guest}
      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = ListSubscriptions.execute(params, opts)
    end
  end
end
