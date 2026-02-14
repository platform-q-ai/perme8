defmodule EntityRelationshipManager.Application.UseCases.CreateEdgeTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.CreateEdge
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "creates edge when schema, type, source, and target are valid" do
      schema = schema_definition()
      created_edge = edge()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, id ->
        {:ok, entity(%{id: id})}
      end)
      |> expect(:get_entity, fn _ws_id, id ->
        {:ok, entity(%{id: id, type: "Company"})}
      end)
      |> expect(:create_edge, fn ws_id, type, source_id, target_id, properties ->
        assert ws_id == workspace_id()
        assert type == "WORKS_AT"
        assert source_id == valid_uuid()
        assert target_id == valid_uuid2()
        assert properties == %{"role" => "Engineer"}
        {:ok, created_edge}
      end)

      assert {:ok, ^created_edge} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "WORKS_AT",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{"role" => "Engineer"}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "WORKS_AT",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when edge type not in schema" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      assert {:error, msg} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "UNKNOWN_EDGE",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "not defined"
    end

    test "returns error for invalid type name" do
      assert {:error, msg} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "123bad",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_binary(msg)
    end

    test "returns error when source entity not found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :source_not_found} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "WORKS_AT",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when target entity not found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id -> {:ok, entity()} end)
      |> expect(:get_entity, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :target_not_found} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "WORKS_AT",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid properties" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      # Validation happens before source/target verification
      # "role" must be a string, not integer
      assert {:error, errors} =
               CreateEdge.execute(
                 workspace_id(),
                 %{
                   type: "WORKS_AT",
                   source_id: valid_uuid(),
                   target_id: valid_uuid2(),
                   properties: %{"role" => 123}
                 },
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_list(errors)
    end
  end
end
