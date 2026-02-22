defmodule Jarga.Webhooks.Application.UseCases.ListInboundWebhookLogsTest do
  use Jarga.DataCase, async: true

  import Mox

  alias Jarga.Webhooks.Application.UseCases.ListInboundWebhookLogs
  alias Jarga.Webhooks.Domain.Entities.InboundWebhook
  alias Jarga.Webhooks.Mocks.MockInboundWebhookRepository

  setup :verify_on_exit!

  defp base_opts do
    [
      inbound_webhook_repository: MockInboundWebhookRepository,
      membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :admin}} end
    ]
  end

  describe "execute/2" do
    test "admin lists inbound webhook logs" do
      logs = [
        %InboundWebhook{id: "inb-1", event_type: "stripe.payment"},
        %InboundWebhook{id: "inb-2", event_type: "github.push"}
      ]

      MockInboundWebhookRepository
      |> expect(:list_for_workspace, fn "ws-123", _opts -> logs end)

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123"}

      assert {:ok, result} = ListInboundWebhookLogs.execute(params, base_opts())
      assert length(result) == 2
    end

    test "non-admin returns forbidden" do
      opts =
        Keyword.merge(base_opts(),
          membership_checker: fn _actor, _workspace_id -> {:ok, %{role: :member}} end
        )

      params = %{actor: %{id: "user-1"}, workspace_id: "ws-123"}

      assert {:error, :forbidden} = ListInboundWebhookLogs.execute(params, opts)
    end
  end
end
