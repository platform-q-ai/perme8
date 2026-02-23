defmodule Webhooks.Infrastructure.Queries.InboundLogQueriesTest do
  use Webhooks.DataCase, async: true

  alias Webhooks.Infrastructure.Queries.InboundLogQueries
  alias Webhooks.Infrastructure.Schemas.InboundLogSchema

  @workspace_id_1 Ecto.UUID.generate()
  @workspace_id_2 Ecto.UUID.generate()

  setup do
    {:ok, log1} =
      insert_log(%{
        workspace_id: @workspace_id_1,
        event_type: "projects.project_created",
        payload: %{},
        received_at: ~U[2026-02-23 10:00:00Z]
      })

    {:ok, log2} =
      insert_log(%{
        workspace_id: @workspace_id_1,
        event_type: "documents.document_created",
        payload: %{},
        received_at: ~U[2026-02-23 12:00:00Z]
      })

    {:ok, other_workspace_log} =
      insert_log(%{
        workspace_id: @workspace_id_2,
        event_type: "projects.project_deleted",
        payload: %{},
        received_at: ~U[2026-02-23 11:00:00Z]
      })

    %{log1: log1, log2: log2, other_workspace_log: other_workspace_log}
  end

  describe "for_workspace/2" do
    test "filters by workspace_id", %{log1: log1, log2: log2} do
      results =
        InboundLogSchema
        |> InboundLogQueries.for_workspace(@workspace_id_1)
        |> Repo.all()

      ids = Enum.map(results, & &1.id)
      assert log1.id in ids
      assert log2.id in ids
      assert length(ids) == 2
    end
  end

  describe "ordered/1" do
    test "orders by received_at desc", %{log1: _, log2: _} do
      results =
        InboundLogSchema
        |> InboundLogQueries.for_workspace(@workspace_id_1)
        |> InboundLogQueries.ordered()
        |> Repo.all()

      received_ats = Enum.map(results, & &1.received_at)
      assert received_ats == Enum.sort(received_ats, {:desc, DateTime})
      # log2 (12:00) should come before log1 (10:00)
      assert hd(results).received_at == ~U[2026-02-23 12:00:00Z]
    end
  end

  defp insert_log(attrs) do
    %InboundLogSchema{}
    |> InboundLogSchema.changeset(attrs)
    |> Repo.insert()
  end
end
