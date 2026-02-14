defmodule EntityRelationshipManager.Application.UseCases.BulkCreateEntitiesTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.BulkCreateEntities
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3 in atomic mode" do
    test "creates all entities when all valid" do
      schema = schema_definition()

      entities_attrs = [
        %{type: "Person", properties: %{"name" => "Alice"}},
        %{type: "Person", properties: %{"name" => "Bob"}}
      ]

      created = [entity(), entity(%{id: valid_uuid2(), properties: %{"name" => "Bob"}})]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:bulk_create_entities, fn ws_id, validated_entities ->
        assert ws_id == workspace_id()
        assert length(validated_entities) == 2
        {:ok, created}
      end)

      assert {:ok, ^created} =
               BulkCreateEntities.execute(workspace_id(), entities_attrs,
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "rejects all in atomic mode when any entity invalid" do
      schema = schema_definition()

      entities_attrs = [
        %{type: "Person", properties: %{"name" => "Alice"}},
        # missing required "name"
        %{type: "Person", properties: %{}}
      ]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      assert {:error, {:validation_errors, errors}} =
               BulkCreateEntities.execute(workspace_id(), entities_attrs,
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_list(errors)
      assert errors != []
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               BulkCreateEntities.execute(
                 workspace_id(),
                 [%{type: "Person", properties: %{"name" => "A"}}],
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end

  describe "execute/3 in partial mode" do
    test "creates valid entities and reports errors for invalid ones" do
      schema = schema_definition()

      entities_attrs = [
        %{type: "Person", properties: %{"name" => "Alice"}},
        # invalid - missing required "name"
        %{type: "Person", properties: %{}},
        %{type: "Person", properties: %{"name" => "Charlie"}}
      ]

      created = [entity(), entity(%{id: valid_uuid2(), properties: %{"name" => "Charlie"}})]

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:bulk_create_entities, fn _ws_id, valid_entities ->
        assert length(valid_entities) == 2
        {:ok, created}
      end)

      assert {:ok, %{created: ^created, errors: errors}} =
               BulkCreateEntities.execute(workspace_id(), entities_attrs,
                 mode: :partial,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert length(errors) == 1
      assert hd(errors).index == 1
    end
  end

  describe "execute/3 batch size limit" do
    test "rejects batches exceeding 1000 items" do
      too_many =
        Enum.map(1..1001, fn i ->
          %{type: "Person", properties: %{"name" => "Person#{i}"}}
        end)

      assert {:error, :batch_too_large} =
               BulkCreateEntities.execute(workspace_id(), too_many,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for empty batch" do
      assert {:error, :empty_batch} =
               BulkCreateEntities.execute(workspace_id(), [],
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end

  describe "execute/3 type name validation" do
    test "rejects entities with invalid type names" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      assert {:error, {:validation_errors, _}} =
               BulkCreateEntities.execute(
                 workspace_id(),
                 [%{type: "123bad", properties: %{}}],
                 mode: :atomic,
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end
  end
end
