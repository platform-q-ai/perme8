defmodule EntityRelationshipManager.Domain.Entities.Entity do
  @moduledoc """
  Domain object representing a graph node (entity) in the workspace.

  An entity has a type (matching an EntityTypeDefinition in the schema),
  properties, and soft-delete support via `deleted_at`.

  This is a pure domain struct with no I/O dependencies.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          type: String.t() | nil,
          properties: map(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          deleted_at: DateTime.t() | nil
        }

  defstruct [:id, :workspace_id, :type, :created_at, :updated_at, :deleted_at, properties: %{}]

  @doc """
  Creates a new Entity from an atom-keyed map.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Returns true if the entity has been soft-deleted.
  """
  @spec deleted?(t()) :: boolean()
  def deleted?(%__MODULE__{deleted_at: nil}), do: false
  def deleted?(%__MODULE__{deleted_at: _}), do: true
end
