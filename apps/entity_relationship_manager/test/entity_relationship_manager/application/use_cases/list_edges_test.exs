defmodule EntityRelationshipManager.Application.UseCases.ListEdgesTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.ListEdges
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns edges list with no filters" do
      edges = [edge()]

      GraphRepositoryMock
      |> expect(:list_edges, fn ws_id, filters ->
        assert ws_id == workspace_id()
        assert filters == %{}
        {:ok, edges}
      end)

      assert {:ok, ^edges} =
               ListEdges.execute(workspace_id(), %{}, graph_repo: GraphRepositoryMock)
    end

    test "validates type filter when provided" do
      GraphRepositoryMock
      |> expect(:list_edges, fn _ws_id, _filters -> {:ok, []} end)

      assert {:ok, _} =
               ListEdges.execute(workspace_id(), %{type: "WORKS_AT"},
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid type name in filters" do
      assert {:error, msg} =
               ListEdges.execute(workspace_id(), %{type: "123bad"},
                 graph_repo: GraphRepositoryMock
               )

      assert is_binary(msg)
    end

    test "validates limit and offset" do
      assert {:error, _} =
               ListEdges.execute(workspace_id(), %{limit: 0}, graph_repo: GraphRepositoryMock)

      assert {:error, _} =
               ListEdges.execute(workspace_id(), %{offset: -1}, graph_repo: GraphRepositoryMock)
    end
  end
end
