defmodule EntityRelationshipManager.Application.UseCases.BulkCreateEdgesTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.BulkCreateEdges
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3 in atomic mode" do
    test "creates all edges when all valid" do
      schema = schema_definition()

      edges_attrs = [
        %{
          type: "WORKS_AT",
          source_id: valid_uuid(),
          target_id: valid_uuid2(),
          properties: %{"role" => "Dev"}
        },
        %{type: "WORKS_AT", source_id: valid_uuid2(), target_id: valid_uuid(), properties: %{}}
      ]

      created = [edge(), edge(%{source_id: valid_uuid2(), target_id: valid_uuid()})]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:bulk_create_edges, fn ws_id, validated_edges ->
        assert ws_id == workspace_id()
        assert length(validated_edges) == 2
        {:ok, created}
      end)

      assert {:ok, ^created} =
               BulkCreateEdges.execute(workspace_id(), edges_attrs,
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "rejects all in atomic mode when any edge invalid" do
      schema = schema_definition()

      edges_attrs = [
        %{type: "WORKS_AT", source_id: valid_uuid(), target_id: valid_uuid2(), properties: %{}},
        # invalid
        %{
          type: "WORKS_AT",
          source_id: valid_uuid(),
          target_id: valid_uuid2(),
          properties: %{"role" => 123}
        }
      ]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      assert {:error, {:validation_errors, errors}} =
               BulkCreateEdges.execute(workspace_id(), edges_attrs,
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_list(errors)
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               BulkCreateEdges.execute(
                 workspace_id(),
                 [
                   %{
                     type: "WORKS_AT",
                     source_id: valid_uuid(),
                     target_id: valid_uuid2(),
                     properties: %{}
                   }
                 ],
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end

  describe "execute/3 in partial mode" do
    test "creates valid edges and reports errors for invalid ones" do
      schema = schema_definition()

      edges_attrs = [
        %{type: "WORKS_AT", source_id: valid_uuid(), target_id: valid_uuid2(), properties: %{}},
        # invalid
        %{
          type: "WORKS_AT",
          source_id: valid_uuid(),
          target_id: valid_uuid2(),
          properties: %{"role" => 123}
        },
        %{type: "WORKS_AT", source_id: valid_uuid2(), target_id: valid_uuid(), properties: %{}}
      ]

      created = [edge(), edge(%{source_id: valid_uuid2(), target_id: valid_uuid()})]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:bulk_create_edges, fn _ws_id, valid_edges ->
        assert length(valid_edges) == 2
        {:ok, created}
      end)

      assert {:ok, %{created: ^created, errors: errors}} =
               BulkCreateEdges.execute(workspace_id(), edges_attrs,
                 mode: :partial,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert length(errors) == 1
      assert hd(errors).index == 1
    end
  end

  describe "execute/3 batch limits" do
    test "rejects batches exceeding 1000 items" do
      too_many =
        Enum.map(1..1001, fn _i ->
          %{type: "WORKS_AT", source_id: valid_uuid(), target_id: valid_uuid2(), properties: %{}}
        end)

      assert {:error, :batch_too_large} =
               BulkCreateEdges.execute(workspace_id(), too_many,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for empty batch" do
      assert {:error, :empty_batch} =
               BulkCreateEdges.execute(workspace_id(), [],
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end

  describe "execute/3 type name validation" do
    test "rejects edges with invalid type names" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      assert {:error, {:validation_errors, _}} =
               BulkCreateEdges.execute(
                 workspace_id(),
                 [
                   %{
                     type: "123bad",
                     source_id: valid_uuid(),
                     target_id: valid_uuid2(),
                     properties: %{}
                   }
                 ],
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end
end
