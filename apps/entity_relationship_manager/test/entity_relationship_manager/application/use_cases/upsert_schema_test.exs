defmodule EntityRelationshipManager.Application.UseCases.UpsertSchemaTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.UpsertSchema
  alias EntityRelationshipManager.Mocks.SchemaRepositoryMock
  import EntityRelationshipManager.UseCaseFixtures

  setup :verify_on_exit!

  describe "execute/3" do
    test "upserts a valid schema" do
      schema = schema_definition()

      attrs = %{
        entity_types: [
          %{
            "name" => "Person",
            "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
          }
        ],
        edge_types: [],
        version: 1
      }

      SchemaRepositoryMock
      |> expect(:upsert_schema, fn ws_id, _attrs ->
        assert ws_id == workspace_id()
        {:ok, schema}
      end)

      assert {:ok, ^schema} =
               UpsertSchema.execute(workspace_id(), attrs, schema_repo: SchemaRepositoryMock)
    end

    test "returns validation errors for invalid schema structure" do
      # Schema with duplicate entity type names
      attrs = %{
        entity_types: [
          %{
            "name" => "Person",
            "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
          },
          %{"name" => "Person", "properties" => [%{"name" => "age", "type" => "integer"}]}
        ],
        edge_types: []
      }

      assert {:error, errors} =
               UpsertSchema.execute(workspace_id(), attrs, schema_repo: SchemaRepositoryMock)

      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "duplicate entity type"))
    end

    test "returns validation errors for invalid property types" do
      attrs = %{
        entity_types: [
          %{"name" => "Person", "properties" => [%{"name" => "name", "type" => "invalid_type"}]}
        ],
        edge_types: []
      }

      assert {:error, errors} =
               UpsertSchema.execute(workspace_id(), attrs, schema_repo: SchemaRepositoryMock)

      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "invalid property type"))
    end

    test "passes version in attrs for optimistic locking" do
      schema = schema_definition(%{version: 2})

      attrs = %{
        entity_types: [
          %{
            "name" => "Person",
            "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
          }
        ],
        edge_types: [],
        version: 1
      }

      SchemaRepositoryMock
      |> expect(:upsert_schema, fn _ws_id, received_attrs ->
        assert received_attrs.version == 1
        {:ok, schema}
      end)

      assert {:ok, _} =
               UpsertSchema.execute(workspace_id(), attrs, schema_repo: SchemaRepositoryMock)
    end

    test "returns error when repo fails" do
      attrs = %{
        entity_types: [
          %{
            "name" => "Person",
            "properties" => [%{"name" => "name", "type" => "string", "required" => true}]
          }
        ],
        edge_types: []
      }

      SchemaRepositoryMock
      |> expect(:upsert_schema, fn _ws_id, _attrs ->
        {:error, :version_conflict}
      end)

      assert {:error, :version_conflict} =
               UpsertSchema.execute(workspace_id(), attrs, schema_repo: SchemaRepositoryMock)
    end
  end
end
