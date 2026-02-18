defmodule EntityRelationshipManager.Application.UseCases.UpsertSchema do
  @moduledoc """
  Use case for creating or updating a workspace's schema definition.

  Validates the schema structure using SchemaValidationPolicy before persisting.
  Supports optimistic locking via version in attrs.
  """

  alias EntityRelationshipManager.Domain.Entities.{
    SchemaDefinition,
    EntityTypeDefinition,
    EdgeTypeDefinition,
    PropertyDefinition
  }

  alias EntityRelationshipManager.Application.RepoConfig

  alias EntityRelationshipManager.Domain.Events.SchemaCreated
  alias EntityRelationshipManager.Domain.Events.SchemaUpdated
  alias EntityRelationshipManager.Domain.Policies.SchemaValidationPolicy

  @default_event_bus Perme8.Events.EventBus

  @doc """
  Validates and upserts a schema definition for a workspace.

  Attrs should contain:
  - `entity_types` - list of entity type maps with string keys
  - `edge_types` - list of edge type maps with string keys
  - `version` (optional) - for optimistic locking

  Returns `{:ok, schema}` on success, `{:error, errors}` on validation failure.
  """
  def execute(workspace_id, attrs, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, RepoConfig.schema_repo())
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    schema_def = build_schema_definition(workspace_id, attrs)

    case SchemaValidationPolicy.validate_schema_structure(schema_def) do
      :ok ->
        is_create = not schema_exists?(schema_repo, workspace_id)

        case schema_repo.upsert_schema(workspace_id, attrs) do
          {:ok, schema} ->
            emit_schema_event(schema, workspace_id, is_create, event_bus)
            {:ok, schema}

          error ->
            error
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp schema_exists?(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  defp build_schema_definition(workspace_id, attrs) do
    entity_types =
      attrs
      |> Map.get(:entity_types, [])
      |> Enum.map(&deserialize_entity_type/1)

    edge_types =
      attrs
      |> Map.get(:edge_types, [])
      |> Enum.map(&deserialize_edge_type/1)

    SchemaDefinition.new(%{
      workspace_id: workspace_id,
      entity_types: entity_types,
      edge_types: edge_types
    })
  end

  defp deserialize_entity_type(%EntityTypeDefinition{} = et), do: et

  defp deserialize_entity_type(map) when is_map(map) do
    if atom_keyed?(map) do
      props = map |> Map.get(:properties, []) |> Enum.map(&deserialize_property/1)
      EntityTypeDefinition.new(%{map | properties: props})
    else
      EntityTypeDefinition.from_map(map)
    end
  end

  defp deserialize_edge_type(%EdgeTypeDefinition{} = et), do: et

  defp deserialize_edge_type(map) when is_map(map) do
    if atom_keyed?(map) do
      props = map |> Map.get(:properties, []) |> Enum.map(&deserialize_property/1)
      EdgeTypeDefinition.new(%{map | properties: props})
    else
      EdgeTypeDefinition.from_map(map)
    end
  end

  defp deserialize_property(%PropertyDefinition{} = pd), do: pd
  defp deserialize_property(map) when is_map(map), do: PropertyDefinition.new(map)

  defp atom_keyed?(map) when map_size(map) > 0 do
    map |> Map.keys() |> List.first() |> is_atom()
  end

  defp atom_keyed?(_), do: false

  defp emit_schema_event(schema, workspace_id, true = _is_create, event_bus) do
    event =
      SchemaCreated.new(%{
        aggregate_id: schema.id,
        actor_id: nil,
        schema_id: schema.id,
        workspace_id: workspace_id
      })

    event_bus.emit(event)
  end

  defp emit_schema_event(schema, workspace_id, false = _is_update, event_bus) do
    event =
      SchemaUpdated.new(%{
        aggregate_id: schema.id,
        actor_id: nil,
        schema_id: schema.id,
        workspace_id: workspace_id
      })

    event_bus.emit(event)
  end
end
