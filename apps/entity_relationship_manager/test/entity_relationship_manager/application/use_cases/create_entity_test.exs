defmodule EntityRelationshipManager.Application.UseCases.CreateEntityTest do
  use ExUnit.Case, async: false

  import Mox

  alias EntityRelationshipManager.Application.UseCases.CreateEntity
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  alias EntityRelationshipManager.Domain.Events.EntityCreated
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  describe "execute/3 - event emission" do
    test "emits EntityCreated event via event_bus" do
      ensure_test_event_bus_started()
      schema = schema_definition()
      created_entity = entity()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:create_entity, fn _ws_id, _type, _props -> {:ok, created_entity} end)

      assert {:ok, ^created_entity} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "Person", properties: %{"name" => "Alice"}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [%EntityCreated{} = event] = TestEventBus.get_events()
      assert event.entity_id == created_entity.id
      assert event.workspace_id == workspace_id()
      assert event.entity_type == "Person"
      assert event.aggregate_id == created_entity.id
    end

    test "does not emit event when creation fails" do
      ensure_test_event_bus_started()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               CreateEntity.execute(
                 workspace_id(),
                 %{type: "Person", properties: %{"name" => "Alice"}},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [] = TestEventBus.get_events()
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

  defp ensure_test_event_bus_started do
    case Process.whereis(TestEventBus) do
      nil ->
        {:ok, _pid} = TestEventBus.start_link([])
        :ok

      _pid ->
        TestEventBus.reset()
    end
  end
end
