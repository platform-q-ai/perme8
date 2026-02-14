defmodule EntityRelationshipManager.Domain.Policies.SchemaValidationPolicy do
  @moduledoc """
  Domain policy for validating schema definitions and entities/edges against schemas.

  Pure functions that validate structural integrity of schema definitions
  and ensure entities and edges conform to their schema types.

  NO I/O, NO database, NO side effects.
  """

  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition
  alias EntityRelationshipManager.Domain.Entities.Entity
  alias EntityRelationshipManager.Domain.Entities.Edge
  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition
  alias EntityRelationshipManager.Domain.Services.PropertyValidator

  @valid_type_name_pattern ~r/^[a-zA-Z][a-zA-Z0-9_]*$/
  @valid_property_types PropertyDefinition.valid_types()

  @doc """
  Validates the structural integrity of a schema definition.

  Checks for:
  - Duplicate entity type names
  - Duplicate edge type names
  - Invalid type names (must be alphanumeric + underscore, non-empty)
  - Duplicate property names within a type
  - Invalid property types

  Returns `:ok` on success, `{:error, [String.t()]}` on failure.
  """
  @spec validate_schema_structure(SchemaDefinition.t()) :: :ok | {:error, [String.t()]}
  def validate_schema_structure(%SchemaDefinition{} = schema) do
    errors =
      []
      |> validate_duplicate_entity_types(schema.entity_types)
      |> validate_duplicate_edge_types(schema.edge_types)
      |> validate_type_names("entity", schema.entity_types)
      |> validate_type_names("edge", schema.edge_types)
      |> validate_properties_in_types("entity", schema.entity_types)
      |> validate_properties_in_types("edge", schema.edge_types)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  @doc """
  Validates an entity's properties against its type definition in the schema.

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @spec validate_entity_against_schema(Entity.t(), SchemaDefinition.t(), String.t()) ::
          :ok | {:error, String.t() | [map()]}
  def validate_entity_against_schema(%Entity{} = entity, %SchemaDefinition{} = schema, type_name) do
    case SchemaDefinition.get_entity_type(schema, type_name) do
      {:ok, entity_type} ->
        case PropertyValidator.validate_properties(entity.properties, entity_type.properties) do
          {:ok, _} -> :ok
          {:error, errors} -> {:error, errors}
        end

      {:error, :not_found} ->
        {:error, "entity type '#{type_name}' is not defined in the schema"}
    end
  end

  @doc """
  Validates an edge's properties against its type definition in the schema.

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @spec validate_edge_against_schema(Edge.t(), SchemaDefinition.t(), String.t()) ::
          :ok | {:error, String.t() | [map()]}
  def validate_edge_against_schema(%Edge{} = edge, %SchemaDefinition{} = schema, type_name) do
    case SchemaDefinition.get_edge_type(schema, type_name) do
      {:ok, edge_type} ->
        case PropertyValidator.validate_properties(edge.properties, edge_type.properties) do
          {:ok, _} -> :ok
          {:error, errors} -> {:error, errors}
        end

      {:error, :not_found} ->
        {:error, "edge type '#{type_name}' is not defined in the schema"}
    end
  end

  # Private helpers

  defp validate_duplicate_entity_types(errors, entity_types) do
    duplicates = find_duplicate_names(entity_types)

    Enum.reduce(duplicates, errors, fn name, acc ->
      ["duplicate entity type name: '#{name}'" | acc]
    end)
  end

  defp validate_duplicate_edge_types(errors, edge_types) do
    duplicates = find_duplicate_names(edge_types)

    Enum.reduce(duplicates, errors, fn name, acc ->
      ["duplicate edge type name: '#{name}'" | acc]
    end)
  end

  defp validate_type_names(errors, kind, types) do
    Enum.reduce(types, errors, fn type, acc ->
      if valid_type_name?(type.name) do
        acc
      else
        ["invalid type name for #{kind} type: '#{type.name}'" | acc]
      end
    end)
  end

  defp validate_properties_in_types(errors, kind, types) do
    Enum.reduce(types, errors, fn type, acc ->
      acc
      |> validate_duplicate_properties(kind, type.name, type.properties)
      |> validate_property_types(kind, type.name, type.properties)
    end)
  end

  defp validate_duplicate_properties(errors, kind, type_name, properties) do
    duplicates = find_duplicate_names(properties)

    Enum.reduce(duplicates, errors, fn name, acc ->
      ["duplicate property name '#{name}' in #{kind} type '#{type_name}'" | acc]
    end)
  end

  defp validate_property_types(errors, kind, type_name, properties) do
    Enum.reduce(properties, errors, fn prop, acc ->
      if prop.type in @valid_property_types do
        acc
      else
        [
          "invalid property type '#{prop.type}' for property '#{prop.name}' in #{kind} type '#{type_name}'"
          | acc
        ]
      end
    end)
  end

  defp find_duplicate_names(items) do
    items
    |> Enum.map(& &1.name)
    |> Enum.frequencies()
    |> Enum.filter(fn {_name, count} -> count > 1 end)
    |> Enum.map(fn {name, _count} -> name end)
  end

  defp valid_type_name?(nil), do: false
  defp valid_type_name?(""), do: false

  defp valid_type_name?(name) when is_binary(name) do
    Regex.match?(@valid_type_name_pattern, name)
  end

  defp valid_type_name?(_), do: false
end
