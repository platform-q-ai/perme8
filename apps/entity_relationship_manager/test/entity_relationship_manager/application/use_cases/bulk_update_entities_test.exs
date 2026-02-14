defmodule EntityRelationshipManager.Application.UseCases.BulkUpdateEntitiesTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.BulkUpdateEntities
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3 in atomic mode" do
    test "updates all entities when all valid" do
      schema = schema_definition()

      updates = [
        %{id: valid_uuid(), properties: %{"name" => "Alice Updated"}},
        %{id: valid_uuid2(), properties: %{"name" => "Bob Updated"}}
      ]

      updated = [
        entity(%{properties: %{"name" => "Alice Updated"}}),
        entity(%{id: valid_uuid2(), properties: %{"name" => "Bob Updated"}})
      ]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:batch_get_entities, fn _ws_id, ids ->
        entities_map =
          ids
          |> Enum.map(fn id -> {id, entity(%{id: id})} end)
          |> Map.new()

        {:ok, entities_map}
      end)
      |> expect(:bulk_update_entities, fn _ws_id, validated_updates ->
        assert length(validated_updates) == 2
        {:ok, updated}
      end)

      assert {:ok, ^updated} =
               BulkUpdateEntities.execute(workspace_id(), updates,
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "rejects all in atomic mode when any update invalid" do
      schema = schema_definition()

      updates = [
        %{id: valid_uuid(), properties: %{"name" => "Valid"}},
        # invalid type
        %{id: valid_uuid2(), properties: %{"name" => 123}}
      ]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:batch_get_entities, fn _ws_id, ids ->
        entities_map =
          ids
          |> Enum.map(fn id -> {id, entity(%{id: id})} end)
          |> Map.new()

        {:ok, entities_map}
      end)

      assert {:error, {:validation_errors, _}} =
               BulkUpdateEntities.execute(workspace_id(), updates,
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when entity not found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:batch_get_entities, fn _ws_id, _ids -> {:ok, %{}} end)

      assert {:error, {:validation_errors, errors}} =
               BulkUpdateEntities.execute(
                 workspace_id(),
                 [%{id: valid_uuid(), properties: %{"name" => "A"}}],
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert hd(errors).reason == :not_found
    end
  end

  describe "execute/3 in partial mode" do
    test "updates valid entities and reports errors for invalid ones" do
      schema = schema_definition()

      updates = [
        %{id: valid_uuid(), properties: %{"name" => "Updated"}},
        # invalid
        %{id: valid_uuid2(), properties: %{"name" => 123}}
      ]

      updated = [entity(%{properties: %{"name" => "Updated"}})]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:batch_get_entities, fn _ws_id, ids ->
        entities_map =
          ids
          |> Enum.map(fn id -> {id, entity(%{id: id})} end)
          |> Map.new()

        {:ok, entities_map}
      end)
      |> expect(:bulk_update_entities, fn _ws_id, valid_updates ->
        assert length(valid_updates) == 1
        {:ok, updated}
      end)

      assert {:ok, %{updated: ^updated, errors: errors}} =
               BulkUpdateEntities.execute(workspace_id(), updates,
                 mode: :partial,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert length(errors) == 1
    end
  end

  describe "execute/3 batch limits" do
    test "rejects batches exceeding 1000 items" do
      too_many =
        Enum.map(1..1001, fn i ->
          %{
            id: "550e8400-e29b-41d4-a716-#{String.pad_leading("#{i}", 12, "0")}",
            properties: %{"name" => "E#{i}"}
          }
        end)

      assert {:error, :batch_too_large} =
               BulkUpdateEntities.execute(workspace_id(), too_many,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for empty batch" do
      assert {:error, :empty_batch} =
               BulkUpdateEntities.execute(workspace_id(), [],
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end
end
