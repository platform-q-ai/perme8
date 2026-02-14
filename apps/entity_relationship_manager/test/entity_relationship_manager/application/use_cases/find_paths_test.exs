defmodule EntityRelationshipManager.Application.UseCases.FindPathsTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.FindPaths
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/4" do
    test "finds paths between two entities" do
      path = [entity(), entity(%{id: valid_uuid2()})]

      GraphRepositoryMock
      |> expect(:find_paths, fn ws_id, source_id, target_id, opts ->
        assert ws_id == workspace_id()
        assert source_id == valid_uuid()
        assert target_id == valid_uuid2()
        assert opts[:max_depth] == 3
        {:ok, [path]}
      end)

      assert {:ok, [^path]} =
               FindPaths.execute(workspace_id(), valid_uuid(), valid_uuid2(),
                 max_depth: 3,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid depth" do
      assert {:error, msg} =
               FindPaths.execute(workspace_id(), valid_uuid(), valid_uuid2(),
                 max_depth: 100,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "depth"
    end

    test "returns error for invalid source UUID" do
      assert {:error, msg} =
               FindPaths.execute(workspace_id(), "bad-uuid", valid_uuid2(),
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "UUID"
    end

    test "returns error for invalid target UUID" do
      assert {:error, msg} =
               FindPaths.execute(workspace_id(), valid_uuid(), "bad-uuid",
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "UUID"
    end

    test "defaults depth when not specified" do
      GraphRepositoryMock
      |> expect(:find_paths, fn _ws_id, _sid, _tid, opts ->
        assert opts[:max_depth] == 1
        {:ok, []}
      end)

      assert {:ok, []} =
               FindPaths.execute(workspace_id(), valid_uuid(), valid_uuid2(),
                 graph_repo: GraphRepositoryMock
               )
    end
  end
end
