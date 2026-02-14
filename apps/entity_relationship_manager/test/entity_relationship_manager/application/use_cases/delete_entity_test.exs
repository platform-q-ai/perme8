defmodule EntityRelationshipManager.Application.UseCases.DeleteEntityTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.DeleteEntity
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "soft-deletes entity and returns deleted edge count" do
      deleted = entity(%{deleted_at: ~U[2026-01-02 00:00:00Z]})

      GraphRepositoryMock
      |> expect(:soft_delete_entity, fn ws_id, entity_id ->
        assert ws_id == workspace_id()
        assert entity_id == valid_uuid()
        {:ok, deleted, 3}
      end)

      assert {:ok, ^deleted, 3} =
               DeleteEntity.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end

    test "returns error when entity not found" do
      GraphRepositoryMock
      |> expect(:soft_delete_entity, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               DeleteEntity.execute(workspace_id(), valid_uuid(), graph_repo: GraphRepositoryMock)
    end

    test "returns error for invalid UUID" do
      assert {:error, msg} =
               DeleteEntity.execute(workspace_id(), "bad-id", graph_repo: GraphRepositoryMock)

      assert msg =~ "UUID"
    end
  end
end
