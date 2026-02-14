defmodule EntityRelationshipManager.Application.UseCases.BulkDeleteEntitiesTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.BulkDeleteEntities
  alias EntityRelationshipManager.Mocks.GraphRepositoryMock

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3 in atomic mode" do
    test "deletes all entities when all IDs valid" do
      ids = [valid_uuid(), valid_uuid2()]

      GraphRepositoryMock
      |> expect(:bulk_soft_delete_entities, fn ws_id, entity_ids ->
        assert ws_id == workspace_id()
        assert entity_ids == ids
        {:ok, 2}
      end)

      assert {:ok, 2} =
               BulkDeleteEntities.execute(workspace_id(), ids,
                 mode: :atomic,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "rejects all in atomic mode when any ID invalid" do
      ids = [valid_uuid(), "bad-uuid"]

      assert {:error, {:validation_errors, errors}} =
               BulkDeleteEntities.execute(workspace_id(), ids,
                 mode: :atomic,
                 graph_repo: GraphRepositoryMock
               )

      assert length(errors) == 1
      assert hd(errors).index == 1
    end
  end

  describe "execute/3 in partial mode" do
    test "deletes valid IDs and reports errors for invalid ones" do
      GraphRepositoryMock
      |> expect(:bulk_soft_delete_entities, fn _ws_id, valid_ids ->
        assert valid_ids == [valid_uuid()]
        {:ok, 1}
      end)

      assert {:ok, %{deleted_count: 1, errors: errors}} =
               BulkDeleteEntities.execute(workspace_id(), [valid_uuid(), "bad-uuid"],
                 mode: :partial,
                 graph_repo: GraphRepositoryMock
               )

      assert length(errors) == 1
      assert hd(errors).index == 1
    end

    test "returns result with zero count when all IDs invalid" do
      assert {:ok, %{deleted_count: 0, errors: errors}} =
               BulkDeleteEntities.execute(workspace_id(), ["bad1", "bad2"],
                 mode: :partial,
                 graph_repo: GraphRepositoryMock
               )

      assert length(errors) == 2
    end
  end

  describe "execute/3 batch limits" do
    test "rejects batches exceeding 1000 items" do
      too_many =
        Enum.map(1..1001, fn i ->
          "550e8400-e29b-41d4-a716-#{String.pad_leading("#{i}", 12, "0")}"
        end)

      assert {:error, :batch_too_large} =
               BulkDeleteEntities.execute(workspace_id(), too_many,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for empty batch" do
      assert {:error, :empty_batch} =
               BulkDeleteEntities.execute(workspace_id(), [], graph_repo: GraphRepositoryMock)
    end
  end
end
