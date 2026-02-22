defmodule Jarga.Webhooks.Infrastructure.Repositories.InboundWebhookRepositoryTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Webhooks.Infrastructure.Repositories.InboundWebhookRepository
  alias Jarga.Webhooks.Domain.Entities.InboundWebhook

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)
    %{user: user, workspace: workspace}
  end

  describe "insert/2" do
    test "creates inbound webhook record and returns domain entity", %{workspace: workspace} do
      attrs = %{
        workspace_id: workspace.id,
        event_type: "external.payment_received",
        payload: %{"amount" => 100},
        source_ip: "192.168.1.1",
        signature_valid: true,
        handler_result: "processed",
        received_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:ok, %InboundWebhook{} = iw} = InboundWebhookRepository.insert(attrs)
      assert iw.workspace_id == workspace.id
      assert iw.event_type == "external.payment_received"
      assert iw.id != nil
    end
  end

  describe "list_for_workspace/2" do
    test "returns inbound webhooks ordered by received_at desc", %{workspace: workspace} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      past = DateTime.add(now, -60, :second)

      import Jarga.WebhookFixtures

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

      results = InboundWebhookRepository.list_for_workspace(workspace.id)
      assert length(results) == 2
      assert Enum.all?(results, &match?(%InboundWebhook{}, &1))
      # Ordered by received_at desc, so newer comes first
      assert hd(results).id == newer.id
    end
  end
end
