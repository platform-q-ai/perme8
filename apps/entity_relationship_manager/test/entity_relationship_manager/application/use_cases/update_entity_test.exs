defmodule EntityRelationshipManager.Application.UseCases.UpdateEntityTest do
  use ExUnit.Case, async: false

  import Mox

  alias EntityRelationshipManager.Application.UseCases.UpdateEntity
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  alias EntityRelationshipManager.Domain.Events.EntityUpdated
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  describe "execute/4 - event emission" do
    test "emits EntityUpdated event via event_bus" do
      ensure_test_event_bus_started()
      schema = schema_definition()
      existing = entity()
      updated = entity(%{properties: %{"name" => "Bob"}})

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id, _opts -> {:ok, existing} end)
      |> expect(:update_entity, fn _ws_id, _id, _props -> {:ok, updated} end)

      assert {:ok, ^updated} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => "Bob"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [%EntityUpdated{} = event] = TestEventBus.get_events()
      assert event.entity_id == updated.id
      assert event.workspace_id == workspace_id()
      assert event.changes == %{"name" => "Bob"}
      assert event.aggregate_id == updated.id
    end

    test "does not emit event when update fails" do
      ensure_test_event_bus_started()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => "Bob"},
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [] = TestEventBus.get_events()
    end

    test "returns error when entity not found" do
      schema = schema_definition()

      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:ok, schema} end)

      GraphRepositoryMock
      |> expect(:get_entity, fn _ws_id, _id, _opts -> {:error, :not_found} end)

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
      |> expect(:get_entity, fn _ws_id, _id, _opts -> {:ok, existing} end)

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
