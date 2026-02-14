defmodule EntityRelationshipManager.Application.UseCases.CreateEntityTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.CreateEntity
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "creates entity when schema and type are valid" do
      schema = schema_definition()
      created_entity = entity()

      SchemaRepositoryMock
      |> expect(:get_schema, fn ws_id ->
        assert ws_id == workspace_id()
        {:ok, schema}
      end)

      GraphRepositoryMock
      |> expect(:create_entity, fn ws_id, type, properties ->
        assert ws_id == workspace_id()
        assert type == "Person"
        assert properties == %{"name" => "Alice"}
        {:ok, created_entity}
      end)

      assert {:ok, ^created_entity} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "Person", properties: %{"name" => "Alice"}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "Person", properties: %{"name" => "Alice"}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when entity type not in schema" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      assert {:error, msg} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "NonExistent", properties: %{}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "not defined"
    end

    test "returns error when properties fail validation" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      # Person requires "name" property
      assert {:error, errors} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "Person", properties: %{}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_list(errors)
      assert Enum.any?(errors, &(&1.field == "name" && &1.constraint == :required))
    end

    test "returns error for invalid type name" do
      assert {:error, msg} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "123invalid", properties: %{}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_binary(msg)
    end
  end
end
