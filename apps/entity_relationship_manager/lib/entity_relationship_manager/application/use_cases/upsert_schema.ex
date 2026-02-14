defmodule EntityRelationshipManager.Application.UseCases.UpsertSchema do
  @moduledoc """
  Use case for creating or updating a workspace's schema definition.

  Validates the schema structure using SchemaValidationPolicy before persisting.
  Supports optimistic locking via version in attrs.
  """

  alias EntityRelationshipManager.Domain.Entities.{
    SchemaDefinition,
    EntityTypeDefinition,
    EdgeTypeDefinition
  }

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Policies.SchemaValidationPolicy

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

    schema_def = build_schema_definition(workspace_id, attrs)

    case SchemaValidationPolicy.validate_schema_structure(schema_def) do
      :ok ->
        schema_repo.upsert_schema(workspace_id, attrs)

      {:error, errors} ->
        {:error, errors}
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

  defp deserialize_entity_type(map) when is_map(map) do
    EntityTypeDefinition.from_map(map)
  end

  defp deserialize_edge_type(map) when is_map(map) do
    EdgeTypeDefinition.from_map(map)
  end
end
