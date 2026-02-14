defmodule EntityRelationshipManager.Application.UseCases.ListEntitiesTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.ListEntities
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns entities list with no filters" do
      entities = [entity()]

      GraphRepositoryMock
      |> expect(:list_entities, fn ws_id, filters ->
        assert ws_id == workspace_id()
        assert filters == %{}
        {:ok, entities}
      end)

      assert {:ok, ^entities} =
               ListEntities.execute(workspace_id(), %{}, graph_repo: GraphRepositoryMock)
    end

    test "validates type filter when provided" do
      entities = [entity()]

      GraphRepositoryMock
      |> expect(:list_entities, fn _ws_id, _filters -> {:ok, entities} end)

      assert {:ok, _} =
               ListEntities.execute(workspace_id(), %{type: "Person"},
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid type name in filters" do
      assert {:error, msg} =
               ListEntities.execute(workspace_id(), %{type: "123invalid"},
                 graph_repo: GraphRepositoryMock
               )

      assert is_binary(msg)
    end

    test "validates limit via TraversalPolicy" do
      assert {:error, msg} =
               ListEntities.execute(workspace_id(), %{limit: 0}, graph_repo: GraphRepositoryMock)

      assert msg =~ "limit"
    end

    test "validates offset via TraversalPolicy" do
      assert {:error, msg} =
               ListEntities.execute(workspace_id(), %{offset: -1},
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "offset"
    end

    test "passes valid limit and offset to repo" do
      GraphRepositoryMock
      |> expect(:list_entities, fn _ws_id, filters ->
        assert filters.limit == 10
        assert filters.offset == 5
        {:ok, []}
      end)

      assert {:ok, []} =
               ListEntities.execute(workspace_id(), %{limit: 10, offset: 5},
                 graph_repo: GraphRepositoryMock
               )
    end
  end
end
