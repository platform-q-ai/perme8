defmodule EntityRelationshipManager.Application.UseCases.DeleteEdgeTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.DeleteEdge
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

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
end
