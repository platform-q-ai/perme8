defmodule EntityRelationshipManager.Application.UseCases.CreateEdge do
  @moduledoc """
  Use case for creating an edge (relationship) in the graph.

  Fetches the schema, validates the edge type exists, validates properties,
  verifies source and target entities exist, then creates via graph repository.
  """

  alias EntityRelationshipManager.Domain.Entities.Edge
  alias EntityRelationshipManager.Domain.Events.EdgeCreated

  alias EntityRelationshipManager.Application.RepoConfig

  alias EntityRelationshipManager.Domain.Policies.{
    SchemaValidationPolicy,
    InputSanitizationPolicy
  }

  @doc """
  Creates an edge in the workspace graph.

  Attrs should contain:
  - `type` - edge type name (must exist in schema)
  - `source_id` - source entity UUID
  - `target_id` - target entity UUID
  - `properties` - map of property values

  Returns `{:ok, edge}` on success, `{:error, reason}` on failure.
  """
  @default_event_bus Perme8.Events.EventBus

  def execute(workspace_id, attrs, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, RepoConfig.schema_repo())
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    type = Map.get(attrs, :type)
    source_id = Map.get(attrs, :source_id)
    target_id = Map.get(attrs, :target_id)
    properties = Map.get(attrs, :properties, %{})

    with :ok <- InputSanitizationPolicy.validate_type_name(type),
         :ok <- InputSanitizationPolicy.validate_uuid(source_id),
         :ok <- InputSanitizationPolicy.validate_uuid(target_id),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id),
         :ok <- validate_edge(schema, type, properties),
         {:ok, edge} <-
           graph_repo.create_edge(workspace_id, type, source_id, target_id, properties) do
      emit_edge_created_event(edge, workspace_id, source_id, target_id, type, event_bus)
      {:ok, edge}
    end
  end

  defp fetch_schema(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, schema} -> {:ok, schema}
      {:error, :not_found} -> {:error, :schema_not_found}
    end
  end

  defp validate_edge(schema, type, properties) do
    edge = Edge.new(%{type: type, properties: properties})
    SchemaValidationPolicy.validate_edge_against_schema(edge, schema, type)
  end

  defp emit_edge_created_event(edge, workspace_id, source_id, target_id, type, event_bus) do
    event =
      EdgeCreated.new(%{
        aggregate_id: edge.id,
        actor_id: nil,
        edge_id: edge.id,
        workspace_id: workspace_id,
        source_id: source_id,
        target_id: target_id,
        edge_type: type
      })

    event_bus.emit(event)
  end
end
