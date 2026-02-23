defmodule Webhooks.Infrastructure.Repositories.InboundLogRepositoryTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Repositories.InboundLogRepository
  alias Webhooks.Domain.Entities.InboundLog

  @workspace_id Ecto.UUID.generate()

  describe "insert/2" do
    test "creates log record and returns domain entity" do
      attrs = %{
        workspace_id: @workspace_id,
        event_type: "projects.project_created",
        payload: %{"key" => "value"},
        source_ip: "192.168.1.1",
        signature_valid: true,
        handler_result: "ok",
        received_at: DateTime.utc_now()
      }

      assert {:ok, %InboundLog{} = entity} = InboundLogRepository.insert(attrs, Repo)

      assert entity.id != nil
      assert entity.workspace_id == @workspace_id
      assert entity.event_type == "projects.project_created"
      assert entity.signature_valid == true
    end

    test "returns changeset error for invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = InboundLogRepository.insert(%{}, Repo)
    end
  end

  describe "list_for_workspace/3" do
    test "returns logs ordered by received_at desc" do
      {:ok, _log1} =
        InboundLogRepository.insert(
          %{
            workspace_id: @workspace_id,
            event_type: "event1",
            payload: %{},
            received_at: ~U[2026-02-23 10:00:00Z]
          },
          Repo
        )

      {:ok, _log2} =
        InboundLogRepository.insert(
          %{
            workspace_id: @workspace_id,
            event_type: "event2",
            payload: %{},
            received_at: ~U[2026-02-23 12:00:00Z]
          },
          Repo
        )

      assert {:ok, logs} = InboundLogRepository.list_for_workspace(@workspace_id, Repo)

      assert length(logs) == 2
      assert Enum.all?(logs, &match?(%InboundLog{}, &1))
      # Most recent first
      assert hd(logs).received_at == ~U[2026-02-23 12:00:00Z]
    end

    test "returns empty list for workspace with no logs" do
      assert {:ok, []} =
               InboundLogRepository.list_for_workspace(Ecto.UUID.generate(), Repo)
    end
  end
end
