defmodule EntityRelationshipManager.Application.UseCases.GetNeighborsTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.GetNeighbors
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns neighbors with valid params" do
      neighbors = [entity(%{id: valid_uuid2()})]

      GraphRepositoryMock
      |> expect(:get_neighbors, fn ws_id, entity_id, opts ->
        assert ws_id == workspace_id()
        assert entity_id == valid_uuid()
        assert opts[:direction] == "out"
        {:ok, neighbors}
      end)

      assert {:ok, ^neighbors} =
               GetNeighbors.execute(workspace_id(), valid_uuid(),
                 direction: "out",
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid direction" do
      assert {:error, msg} =
               GetNeighbors.execute(workspace_id(), valid_uuid(),
                 direction: "invalid",
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "direction"
    end

    test "returns error for invalid entity UUID" do
      assert {:error, msg} =
               GetNeighbors.execute(workspace_id(), "bad-uuid", graph_repo: GraphRepositoryMock)

      assert msg =~ "UUID"
    end

    test "validates entity type filter" do
      assert {:error, msg} =
               GetNeighbors.execute(workspace_id(), valid_uuid(),
                 entity_type: "123invalid",
                 graph_repo: GraphRepositoryMock
               )

      assert is_binary(msg)
    end

    test "validates edge type filter" do
      assert {:error, msg} =
               GetNeighbors.execute(workspace_id(), valid_uuid(),
                 edge_type: "123invalid",
                 graph_repo: GraphRepositoryMock
               )

      assert is_binary(msg)
    end

    test "passes valid options to repo" do
      GraphRepositoryMock
      |> expect(:get_neighbors, fn _ws_id, _id, opts ->
        assert opts[:direction] == "both"
        assert opts[:entity_type] == "Person"
        assert opts[:edge_type] == "WORKS_AT"
        {:ok, []}
      end)

      assert {:ok, []} =
               GetNeighbors.execute(workspace_id(), valid_uuid(),
                 direction: "both",
                 entity_type: "Person",
                 edge_type: "WORKS_AT",
                 graph_repo: GraphRepositoryMock
               )
    end

    test "defaults direction to both when not specified" do
      GraphRepositoryMock
      |> expect(:get_neighbors, fn _ws_id, _id, opts ->
        assert opts[:direction] == "both"
        {:ok, []}
      end)

      assert {:ok, []} =
               GetNeighbors.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end
  end
end
