defmodule EntityRelationshipManager.Application.UseCases.CreateEntity do
  @moduledoc """
  Use case for creating an entity in the graph.

  Fetches the workspace schema, validates the entity type exists,
  validates properties against the schema, sanitizes the type name,
  then creates via the graph repository.
  """

  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Events.EntityCreated

  alias EntityRelationshipManager.Application.RepoConfig

  alias EntityRelationshipManager.Domain.Policies.{
    SchemaValidationPolicy,
    InputSanitizationPolicy
  }

  @doc """
  Creates an entity in the workspace graph.

  Attrs should contain:
  - `type` - entity type name (must exist in schema)
  - `properties` - map of property values

  Returns `{:ok, entity}` on success, `{:error, reason}` on failure.
  """
  @default_event_bus Perme8.Events.EventBus

  def execute(workspace_id, attrs, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, RepoConfig.schema_repo())
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    type = Map.get(attrs, :type)
    properties = Map.get(attrs, :properties, %{})

    with :ok <- InputSanitizationPolicy.validate_type_name(type),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id),
         :ok <- validate_entity(schema, type, properties),
         {:ok, entity} <- graph_repo.create_entity(workspace_id, type, properties) do
      emit_entity_created_event(entity, workspace_id, type, properties, event_bus)
      {:ok, entity}
    end
  end

  defp fetch_schema(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, schema} -> {:ok, schema}
      {:error, :not_found} -> {:error, :schema_not_found}
    end
  end

  defp validate_entity(schema, type, properties) do
    entity = Entity.new(%{type: type, properties: properties})
    SchemaValidationPolicy.validate_entity_against_schema(entity, schema, type)
  end

  # Part 2: thread actor_id from controller layer for audit trail attribution
  defp emit_entity_created_event(entity, workspace_id, type, properties, event_bus) do
    event =
      EntityCreated.new(%{
        aggregate_id: entity.id,
        actor_id: nil,
        entity_id: entity.id,
        workspace_id: workspace_id,
        entity_type: type,
        properties: properties
      })

    event_bus.emit(event)
  end
end
