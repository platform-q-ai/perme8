defmodule EntityRelationshipManager.Application.UseCases.UpsertSchemaTest do
  use ExUnit.Case, async: false

  import Mox

  alias EntityRelationshipManager.Application.UseCases.UpsertSchema
  alias EntityRelationshipManager.Mocks.SchemaRepositoryMock
  import EntityRelationshipManager.UseCaseFixtures

  alias EntityRelationshipManager.Domain.Events.SchemaCreated
  alias EntityRelationshipManager.Domain.Events.SchemaUpdated

  setup :verify_on_exit!

  describe "execute/3 - event emission" do
    test "emits SchemaCreated event when schema does not exist" do
      ensure_test_event_bus_started()
      schema = schema_definition()

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
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)
      |> expect(:upsert_schema, fn _ws_id, _attrs -> {:ok, schema} end)

      assert {:ok, ^schema} =
               UpsertSchema.execute(workspace_id(), attrs,
                 schema_repo: SchemaRepositoryMock,
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [%SchemaCreated{} = event] = Perme8.Events.TestEventBus.get_events()
      assert event.schema_id == schema.id
      assert event.workspace_id == workspace_id()
      assert event.aggregate_id == schema.id
    end

    test "emits SchemaUpdated event when schema already exists" do
      ensure_test_event_bus_started()

      existing_schema = schema_definition()
      updated_schema = schema_definition(%{version: 2})

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
      |> expect(:get_schema, fn _ws_id -> {:ok, existing_schema} end)
      |> expect(:upsert_schema, fn _ws_id, _attrs -> {:ok, updated_schema} end)

      assert {:ok, ^updated_schema} =
               UpsertSchema.execute(workspace_id(), attrs,
                 schema_repo: SchemaRepositoryMock,
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [%SchemaUpdated{} = event] = Perme8.Events.TestEventBus.get_events()
      assert event.schema_id == updated_schema.id
      assert event.workspace_id == workspace_id()
      assert event.aggregate_id == updated_schema.id
    end

    test "does not emit event when validation fails" do
      ensure_test_event_bus_started()

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

      assert {:error, _errors} =
               UpsertSchema.execute(workspace_id(), attrs,
                 schema_repo: SchemaRepositoryMock,
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [] = Perme8.Events.TestEventBus.get_events()
    end
  end

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
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)
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
      |> expect(:get_schema, fn _ws_id -> {:ok, schema_definition()} end)
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
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)
      |> expect(:upsert_schema, fn _ws_id, _attrs ->
        {:error, :version_conflict}
      end)

      assert {:error, :version_conflict} =
               UpsertSchema.execute(workspace_id(), attrs, schema_repo: SchemaRepositoryMock)
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(Perme8.Events.TestEventBus) do
      nil ->
        {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
        :ok

      _pid ->
        Perme8.Events.TestEventBus.reset()
    end
  end
end
