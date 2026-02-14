defmodule EntityRelationshipManager.UseCaseFixtures do
  @moduledoc """
  Shared fixtures for use case tests.

  Provides pre-built domain entities for testing use cases with mocked repositories.
  """

  alias EntityRelationshipManager.Domain.Entities.{
    SchemaDefinition,
    EntityTypeDefinition,
    EdgeTypeDefinition,
    PropertyDefinition,
    Entity,
    Edge
  }

  @workspace_id "ws-test-001"

  def workspace_id, do: @workspace_id

  def valid_uuid, do: "550e8400-e29b-41d4-a716-446655440000"
  def valid_uuid2, do: "550e8400-e29b-41d4-a716-446655440001"
  def valid_uuid3, do: "550e8400-e29b-41d4-a716-446655440002"

  def schema_definition(overrides \\ %{}) do
    defaults = %{
      id: "schema-001",
      workspace_id: @workspace_id,
      version: 1,
      entity_types: [person_type(), company_type()],
      edge_types: [works_at_type()]
    }

    SchemaDefinition.new(Map.merge(defaults, overrides))
  end

  def person_type do
    EntityTypeDefinition.new(%{
      name: "Person",
      properties: [
        PropertyDefinition.new(%{name: "name", type: :string, required: true}),
        PropertyDefinition.new(%{name: "age", type: :integer, required: false})
      ]
    })
  end

  def company_type do
    EntityTypeDefinition.new(%{
      name: "Company",
      properties: [
        PropertyDefinition.new(%{name: "name", type: :string, required: true}),
        PropertyDefinition.new(%{name: "founded", type: :integer, required: false})
      ]
    })
  end

  def works_at_type do
    EdgeTypeDefinition.new(%{
      name: "WORKS_AT",
      properties: [
        PropertyDefinition.new(%{name: "role", type: :string, required: false}),
        PropertyDefinition.new(%{name: "since", type: :integer, required: false})
      ]
    })
  end

  def entity(overrides \\ %{}) do
    defaults = %{
      id: valid_uuid(),
      workspace_id: @workspace_id,
      type: "Person",
      properties: %{"name" => "Alice"},
      created_at: ~U[2026-01-01 00:00:00Z],
      updated_at: ~U[2026-01-01 00:00:00Z]
    }

    Entity.new(Map.merge(defaults, overrides))
  end

  def edge(overrides \\ %{}) do
    defaults = %{
      id: valid_uuid3(),
      workspace_id: @workspace_id,
      type: "WORKS_AT",
      source_id: valid_uuid(),
      target_id: valid_uuid2(),
      properties: %{"role" => "Engineer"},
      created_at: ~U[2026-01-01 00:00:00Z],
      updated_at: ~U[2026-01-01 00:00:00Z]
    }

    Edge.new(Map.merge(defaults, overrides))
  end
end
