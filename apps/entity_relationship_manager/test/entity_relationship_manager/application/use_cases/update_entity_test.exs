defmodule EntityRelationshipManager.Application.UseCases.UpdateEntityTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.UpdateEntity
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/4" do
    test "updates entity with valid properties" do
      schema = schema_definition()
      existing = entity()
      updated = entity(%{properties: %{"name" => "Bob", "age" => 30}})

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id -> {:ok, existing} end)
      |> expect(:update_entity, fn ws_id, entity_id, properties ->
        assert ws_id == workspace_id()
        assert entity_id == valid_uuid()
        assert properties == %{"name" => "Bob", "age" => 30}
        {:ok, updated}
      end)

      assert {:ok, ^updated} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => "Bob", "age" => 30},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when entity not found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => "Bob"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => "Bob"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid properties" do
      schema = schema_definition()
      existing = entity()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id -> {:ok, existing} end)

      # "name" is required but we're providing a non-string value
      assert {:error, errors} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => 123},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_list(errors)
    end

    test "returns error for invalid UUID" do
      assert {:error, msg} =
               UpdateEntity.execute(
                 workspace_id(),
                 "bad-uuid",
                 %{},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "UUID"
    end
  end
end
