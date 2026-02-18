defmodule EntityRelationshipManager.Application.UseCases.DeleteEdgeTest do
  use ExUnit.Case, async: false

  import Mox

  alias EntityRelationshipManager.Application.UseCases.DeleteEdge
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  alias EntityRelationshipManager.Domain.Events.EdgeDeleted
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  describe "execute/3 - event emission" do
    test "emits EdgeDeleted event via event_bus" do
      ensure_test_event_bus_started()
      deleted = edge(%{deleted_at: ~U[2026-01-02 00:00:00Z]})

      GraphRepositoryMock
      |> expect(:soft_delete_edge, fn _ws_id, _id -> {:ok, deleted} end)

      assert {:ok, ^deleted} =
               DeleteEdge.execute(workspace_id(), valid_uuid3(),
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [%EdgeDeleted{} = event] = TestEventBus.get_events()
      assert event.edge_id == deleted.id
      assert event.workspace_id == workspace_id()
      assert event.aggregate_id == deleted.id
    end

    test "does not emit event when deletion fails" do
      ensure_test_event_bus_started()

      GraphRepositoryMock
      |> expect(:soft_delete_edge, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               DeleteEdge.execute(workspace_id(), valid_uuid(),
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [] = TestEventBus.get_events()
    end
  end

  describe "execute/3" do
    test "soft-deletes edge" do
      deleted = edge(%{deleted_at: ~U[2026-01-02 00:00:00Z]})

      GraphRepositoryMock
      |> expect(:soft_delete_edge, fn ws_id, edge_id ->
        assert ws_id == workspace_id()
        assert edge_id == valid_uuid3()
        {:ok, deleted}
      end)

      assert {:ok, ^deleted} =
               DeleteEdge.execute(workspace_id(), valid_uuid3(), graph_repo: GraphRepositoryMock)
    end

    test "returns error when edge not found" do
      GraphRepositoryMock
      |> expect(:soft_delete_edge, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               DeleteEdge.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end

    test "returns error for invalid UUID" do
      assert {:error, msg} =
               DeleteEdge.execute(workspace_id(), "bad-uuid", graph_repo: GraphRepositoryMock)

      assert msg =~ "UUID"
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(TestEventBus) do
      nil ->
        {:ok, _pid} = TestEventBus.start_link([])
        :ok

      _pid ->
        TestEventBus.reset()
    end
  end
end
