defmodule EntityRelationshipManager.Infrastructure.Schemas.SchemaDefinitionSchema do
  @moduledoc """
  Ecto schema for entity_schemas database persistence.

  Maps to the `entity_schemas` PostgreSQL table which stores workspace
  schema definitions (entity types and edge types as JSONB arrays).

  Domain entity: `EntityRelationshipManager.Domain.Entities.SchemaDefinition`
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias EntityRelationshipManager.Domain.Entities.SchemaDefinition
  alias EntityRelationshipManager.Domain.Entities.EntityTypeDefinition
  alias EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "entity_schemas" do
    field(:workspace_id, :binary_id)
    field(:entity_types, {:array, :map}, default: [])
    field(:edge_types, {:array, :map}, default: [])
    field(:version, :integer, default: 1)
    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new schema definition.

  Requires workspace_id, entity_types, and edge_types.
  """
  def create_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:workspace_id, :entity_types, :edge_types])
    |> validate_required([:workspace_id, :entity_types, :edge_types])
    |> unique_constraint(:workspace_id)
  end

  @doc """
  Changeset for updating an existing schema definition.

  Uses optimistic locking on the version field.
  """
  def update_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:entity_types, :edge_types, :version])
    |> validate_required([:entity_types, :edge_types])
    |> optimistic_lock(:version)
  end

  @doc """
  Changeset for updating a schema without optimistic locking.

  Used for idempotent upserts (e.g., BDD setup scenarios) where the caller
  does not provide a version and simply wants to replace the schema contents.
  Increments version manually.
  """
  def force_update_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:entity_types, :edge_types])
    |> validate_required([:entity_types, :edge_types])
    |> put_change(:version, (struct.version || 0) + 1)
  end

  @doc """
  Converts an Ecto schema record to a domain `SchemaDefinition` struct.

  Deserializes JSONB entity_types and edge_types into their respective
  domain value objects.
  """
  @spec to_entity(%__MODULE__{}) :: SchemaDefinition.t()
  def to_entity(%__MODULE__{} = schema) do
    entity_types =
      schema.entity_types
      |> Enum.map(&EntityTypeDefinition.from_map/1)

    edge_types =
      schema.edge_types
      |> Enum.map(&EdgeTypeDefinition.from_map/1)

    SchemaDefinition.new(%{
      id: schema.id,
      workspace_id: schema.workspace_id,
      entity_types: entity_types,
      edge_types: edge_types,
      version: schema.version,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end
