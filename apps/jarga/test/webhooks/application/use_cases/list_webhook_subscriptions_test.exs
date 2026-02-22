defmodule Jarga.Webhooks.Application.UseCases.ListWebhookSubscriptionsTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.ListWebhookSubscriptions
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
    test "admin lists subscriptions for workspace" do
      subscriptions = [
        %WebhookSubscription{id: "sub-1", url: "https://a.com/hook"},
        %WebhookSubscription{id: "sub-2", url: "https://b.com/hook"}
      ]

      MockWebhookRepository
      |> expect(:list_for_workspace, fn "ws-123", _opts -> subscriptions end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123"}

      assert {:ok, result} = ListWebhookSubscriptions.execute(params, base_opts())
      assert length(result) == 2
    end

    test "non-admin returns forbidden" do
      opts =
        Keyword.merge(base_opts(),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123"}

      assert {:error, :forbidden} = ListWebhookSubscriptions.execute(params, opts)
    end
  end
end
