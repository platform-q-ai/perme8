defmodule EntityRelationshipManager.Application.UseCases.UpdateEdgeTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.UpdateEdge
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/4" do
    test "updates edge with valid properties" do
      schema = schema_definition()
      existing = edge()
      updated = edge(%{properties: %{"role" => "Manager"}})

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_edge, fn _ws_id, _id -> {:ok, existing} end)
      |> expect(:update_edge, fn ws_id, edge_id, properties ->
        assert ws_id == workspace_id()
        assert edge_id == valid_uuid3()
        assert properties == %{"role" => "Manager"}
        {:ok, updated}
      end)

      assert {:ok, ^updated} =
               UpdateEdge.execute(
                 workspace_id(),
                 valid_uuid3(),
                 %{"role" => "Manager"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when edge not found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_edge, fn _ws_id, _id -> {:error, :not_found} end)

      assert {:error, :not_found} =
               UpdateEdge.execute(
                 workspace_id(),
                 valid_uuid3(),
                 %{"role" => "Manager"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error when schema not found" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               UpdateEdge.execute(
                 workspace_id(),
                 valid_uuid3(),
                 %{"role" => "Manager"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )
    end

    test "returns error for invalid properties" do
      schema = schema_definition()
      existing = edge()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_edge, fn _ws_id, _id -> {:ok, existing} end)

      assert {:error, errors} =
               UpdateEdge.execute(
                 workspace_id(),
                 valid_uuid3(),
                 %{"role" => 123},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert is_list(errors)
    end

    test "returns error for invalid UUID" do
      assert {:error, msg} =
               UpdateEdge.execute(
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
