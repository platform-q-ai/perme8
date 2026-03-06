defmodule EntityRelationshipManager.Application.UseCases.UpdateEntityTest do
  use ExUnit.Case, async: true

  import Mox

  alias EntityRelationshipManager.Application.UseCases.UpdateEntity
  alias EntityRelationshipManager.Mocks.{SchemaRepositoryMock, GraphRepositoryMock}

  import EntityRelationshipManager.UseCaseFixtures

  alias EntityRelationshipManager.Domain.Events.EntityUpdated
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/5 - event emission" do
    test "emits EntityUpdated event via event_bus" do
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
                 valid_uuid(),
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock,
                 event_bus: TestEventBus
               )

      assert [%EntityUpdated{} = event] = TestEventBus.get_events()
      assert event.entity_id == updated.id
      assert event.workspace_id == workspace_id()
      assert event.changes == %{"name" => "Bob"}
      assert event.aggregate_id == updated.id
      assert event.actor_id == valid_uuid()
    end

    test "does not emit event when update fails" do
      SchemaRepositoryMock
      |> expect(:get_schema, fn _ws_id -> {:error, :not_found} end)

      assert {:error, :schema_not_found} =
               UpdateEntity.execute(
                 workspace_id(),
                 valid_uuid(),
                 %{"name" => "Bob"},
                 valid_uuid(),
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
                 valid_uuid(),
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
                 valid_uuid(),
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
                 valid_uuid(),
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
                 valid_uuid(),
                 schema_repo: SchemaRepositoryMock,
                 graph_repo: GraphRepositoryMock
               )

      assert msg =~ "UUID"
    end
  end
end
