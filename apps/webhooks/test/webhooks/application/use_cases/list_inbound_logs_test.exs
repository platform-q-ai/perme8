defmodule Webhooks.Application.UseCases.ListInboundLogsTest do
  use ExUnit.Case, async: true

  alias Webhooks.Application.UseCases.ListInboundLogs
  alias Webhooks.Domain.Entities.InboundLog

  defmodule MockInboundLogRepo do
    def list_for_workspace("ws-123", _repo) do
      {:ok,
       [
         InboundLog.new(%{
           id: "log-1",
           workspace_id: "ws-123",
           event_type: "order.created",
           signature_valid: true,
           received_at: ~U[2026-01-01 00:00:00Z]
         }),
         InboundLog.new(%{
           id: "log-2",
           workspace_id: "ws-123",
           event_type: "order.updated",
           signature_valid: false,
           received_at: ~U[2026-01-02 00:00:00Z]
         })
       ]}
    end

    def list_for_workspace("ws-empty", _repo) do
      {:ok, []}
    end
  end

  describe "execute/2 - successful listing" do
    test "returns list of inbound logs for workspace" do
      params = %{workspace_id: "ws-123", member_role: :admin}
      opts = [inbound_log_repository: MockInboundLogRepo]

      assert {:ok, logs} = ListInboundLogs.execute(params, opts)
      assert length(logs) == 2
    end

    test "returns empty list when no logs exist" do
      params = %{workspace_id: "ws-empty", member_role: :owner}
      opts = [inbound_log_repository: MockInboundLogRepo]

      assert {:ok, []} = ListInboundLogs.execute(params, opts)
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns forbidden for non-admin roles" do
      params = %{workspace_id: "ws-123", member_role: :member}
      opts = [inbound_log_repository: MockInboundLogRepo]

      assert {:error, :forbidden} = ListInboundLogs.execute(params, opts)
    end

    test "returns forbidden for guest role" do
      params = %{workspace_id: "ws-123", member_role: :guest}
      opts = [inbound_log_repository: MockInboundLogRepo]

      assert {:error, :forbidden} = ListInboundLogs.execute(params, opts)
    end
  end
end
