defmodule EntityRelationshipManager.Application.UseCases.GetEdgeTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.GetEdge
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns edge when found" do
      expected = edge()

      GraphRepositoryMock
      |> expect(:get_edge, fn ws_id, edge_id ->
        assert ws_id == workspace_id()
        assert edge_id == valid_uuid3()
        {:ok, expected}
      end)

      assert {:ok, ^expected} =
               GetEdge.execute(workspace_id(), valid_uuid3(), graph_repo: GraphRepositoryMock)
    end

    test "returns error when edge not found" do
      GraphRepositoryMock
      |> expect(:get_edge, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               GetEdge.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end

    test "returns error for invalid UUID" do
      assert {:error, msg} =
               GetEdge.execute(workspace_id(), "bad-uuid", graph_repo: GraphRepositoryMock)

      assert msg =~ "UUID"
    end
  end
end
