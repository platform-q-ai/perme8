defmodule EntityRelationshipManager.Application.UseCases.TraverseTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.Traverse
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "traverses graph from start entity" do
      results = [entity(), entity(%{id: valid_uuid2()})]

      GraphRepositoryMock
      |> expect(:traverse, fn ws_id, start_id, opts ->
        assert ws_id == workspace_id()
        assert start_id == valid_uuid()
        assert opts[:max_depth] == 3
        assert opts[:direction] == "out"
        assert opts[:limit] == 50
        {:ok, results}
      end)

      assert {:ok, ^results} =
               Traverse.execute(workspace_id(), valid_uuid(),
                 max_depth: 3,
                 direction: "out",
                 limit: 50,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid depth" do
      assert {:error, msg} =
               Traverse.execute(workspace_id(), valid_uuid(),
                 max_depth: 0,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "depth"
    end

    test "returns error for invalid direction" do
      assert {:error, msg} =
               Traverse.execute(workspace_id(), valid_uuid(),
                 direction: "sideways",
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "direction"
    end

    test "returns error for invalid limit" do
      assert {:error, msg} =
               Traverse.execute(workspace_id(), valid_uuid(),
                 limit: 0,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "limit"
    end

    test "returns error for invalid start UUID" do
      assert {:error, msg} =
               Traverse.execute(workspace_id(), "bad-uuid", graph_repo: GraphRepositoryMock)

      assert msg =~ "UUID"
    end

    test "uses defaults when options not provided" do
      GraphRepositoryMock
      |> expect(:traverse, fn _ws_id, _id, opts ->
        assert opts[:max_depth] == 1
        assert opts[:direction] == "both"
        {:ok, []}
      end)

      assert {:ok, []} =
               Traverse.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end
  end
end
