defmodule Webhooks.Application.UseCases.UpdateSubscriptionTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.UpdateSubscription
  alias Webhooks.Domain.Entities.Subscription

  defmodule MockSubscriptionRepo do
    def update("sub-123", attrs, _repo) do
      {:ok,
       Subscription.new(%{
         id: "sub-123",
         url: Map.get(attrs, :url, "https://example.com/hook"),
         secret: "supersecret",
         event_types: Map.get(attrs, :event_types, ["project.created"]),
         is_active: Map.get(attrs, :is_active, true),
         workspace_id: "ws-123"
       })}
    end

    def update("sub-missing", _attrs, _repo) do
      {:error, :not_found}
    end
  end

  describe "execute/2 - successful update" do
    test "updates url, event_types, and is_active" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-123",
        attrs: %{
          url: "https://new-url.com/webhook",
          event_types: ["document.deleted"],
          is_active: false
        }
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, %Subscription{} = subscription} = UpdateSubscription.execute(params, opts)
      assert subscription.url == "https://new-url.com/webhook"
      assert subscription.event_types == ["document.deleted"]
      assert subscription.is_active == false
    end

    test "does not return secret in response" do
      params = %{
        workspace_id: "ws-123",
        member_role: :owner,
        subscription_id: "sub-123",
        attrs: %{url: "https://updated.com/hook"}
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:ok, %Subscription{} = subscription} = UpdateSubscription.execute(params, opts)
      assert subscription.secret == nil
    end
  end

  describe "execute/2 - not found" do
    test "returns not_found for missing subscription" do
      params = %{
        workspace_id: "ws-123",
        member_role: :admin,
        subscription_id: "sub-missing",
        attrs: %{url: "https://example.com/hook"}
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :not_found} = UpdateSubscription.execute(params, opts)
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden for non-admin roles" do
      params = %{
        workspace_id: "ws-123",
        member_role: :member,
        subscription_id: "sub-123",
        attrs: %{url: "https://example.com/hook"}
      }

      opts = [subscription_repository: MockSubscriptionRepo]

      assert {:error, :forbidden} = UpdateSubscription.execute(params, opts)
    end
  end
end
