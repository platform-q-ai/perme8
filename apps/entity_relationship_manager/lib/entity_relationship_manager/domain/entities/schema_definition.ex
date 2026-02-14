defmodule EntityRelationshipManager.Domain.Entities.SchemaDefinition do
  @moduledoc """
  Domain entity representing a workspace's schema definition.

  A schema definition holds the entity types and edge types that define
  the structure of a workspace's graph. It acts as a type system for
  entities and edges within the workspace.

  This is a pure domain struct with no I/O dependencies.
  """

  alias EntityRelationshipManager.Domain.Entities.EntityTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          entity_types: [EntityTypeDefinition.t()],
          edge_types: [EdgeTypeDefinition.t()],
          version: non_neg_integer() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :workspace_id,
    :version,
    :created_at,
    :updated_at,
    entity_types: [],
    edge_types: []
  ]

  @doc """
  Creates a new SchemaDefinition from an atom-keyed map.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Returns the entity type definition with the given name.

  Returns `{:ok, entity_type}` if found, `{:error, :not_found}` otherwise.
  """
  @spec get_entity_type(t(), String.t()) :: {:ok, EntityTypeDefinition.t()} | {:error, :not_found}
  def get_entity_type(%__MODULE__{entity_types: entity_types}, name) do
    case Enum.find(entity_types, &(&1.name == name)) do
      nil -> {:error, :not_found}
      entity_type -> {:ok, entity_type}
    end
  end

  @doc """
  Returns the edge type definition with the given name.

  Returns `{:ok, edge_type}` if found, `{:error, :not_found}` otherwise.
  """
  @spec get_edge_type(t(), String.t()) :: {:ok, EdgeTypeDefinition.t()} | {:error, :not_found}
  def get_edge_type(%__MODULE__{edge_types: edge_types}, name) do
    case Enum.find(edge_types, &(&1.name == name)) do
      nil -> {:error, :not_found}
      edge_type -> {:ok, edge_type}
    end
  end

  @doc """
  Returns true if the schema contains an entity type with the given name.
  """
  @spec has_entity_type?(t(), String.t()) :: boolean()
  def has_entity_type?(%__MODULE__{entity_types: entity_types}, name) do
    Enum.any?(entity_types, &(&1.name == name))
  end

  @doc """
  Returns true if the schema contains an edge type with the given name.
  """
  @spec has_edge_type?(t(), String.t()) :: boolean()
  def has_edge_type?(%__MODULE__{edge_types: edge_types}, name) do
    Enum.any?(edge_types, &(&1.name == name))
  end
end
