defmodule Jarga.Webhooks.Application.UseCases.GetWebhookSubscriptionTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.GetWebhookSubscription
  alias Jarga.Webhooks.Domain.Entities.WebhookSubscription
  alias Jarga.Webhooks.Mocks.MockWebhookRepository

  setup :verify_on_exit!

  defp base_opts do
    [
      webhook_repository: MockWebhookRepository,
      membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :admin}} end
    ]
  end

  describe "execute/2" do
    test "admin gets subscription by ID" do
      subscription = %WebhookSubscription{id: "sub-1", url: "https://example.com/hook"}

      MockWebhookRepository
      |> expect(:get, fn "sub-1", _opts -> subscription end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-1"}

      assert {:ok, result} = GetWebhookSubscription.execute(params, base_opts())
      assert result.id == "sub-1"
    end

    test "returns not_found when subscription doesn't exist" do
      MockWebhookRepository
      |> expect(:get, fn "sub-999", _opts -> nil end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-999"}

      assert {:error, :not_found} = GetWebhookSubscription.execute(params, base_opts())
    end

    test "non-admin returns forbidden" do
      opts =
        Keyword.merge(base_opts(),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123", subscription_id: "sub-1"}

      assert {:error, :forbidden} = GetWebhookSubscription.execute(params, opts)
    end
  end
end
