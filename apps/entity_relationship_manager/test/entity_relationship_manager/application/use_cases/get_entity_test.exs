defmodule EntityRelationshipManager.Application.UseCases.GetEntityTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.GetEntity
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns entity when found" do
      expected = entity()

      GraphRepositoryMock
      |> expect(:get_entity, fn ws_id, entity_id ->
        assert ws_id == workspace_id()
        assert entity_id == valid_uuid()
        {:ok, expected}
      end)

      assert {:ok, ^expected} =
               GetEntity.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end

    test "returns error when entity not found" do
      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _entity_id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               GetEntity.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end

    test "returns error for invalid UUID format" do
      assert {:error, msg} =
               GetEntity.execute(workspace_id(), "not-a-uuid", graph_repo: GraphRepositoryMock)

      assert msg =~ "UUID"
    end
  end
end
