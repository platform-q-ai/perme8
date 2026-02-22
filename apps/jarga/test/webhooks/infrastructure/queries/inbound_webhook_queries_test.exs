defmodule Jarga.Webhooks.Infrastructure.Queries.InboundWebhookQueriesTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.WebhookFixtures

  alias Jarga.Webhooks.Infrastructure.Queries.InboundWebhookQueries

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)
    %{user: user, workspace: workspace}
  end

  describe "for_workspace/2" do
    test "filters by workspace_id", %{workspace: workspace} do
      iw =
        inbound_webhook_fixture(%{
          workspace_id: workspace.id
        })

      results =
        InboundWebhookQueries.for_workspace(workspace.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == iw.id
    end
  end

  describe "ordered/1" do
    test "orders by received_at desc", %{workspace: workspace} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      past = DateTime.add(now, -60, :second)

      _older =
        inbound_webhook_fixture(%{
          workspace_id: workspace.id,
          received_at: past,
          event_type: "older"
        })

      newer =
        inbound_webhook_fixture(%{
          workspace_id: workspace.id,
          received_at: now,
          event_type: "newer"
        })

      results =
        InboundWebhookQueries.for_workspace(workspace.id)
        |> InboundWebhookQueries.ordered()
        |> Repo.all()

      assert hd(results).id == newer.id
    end
  end
end
