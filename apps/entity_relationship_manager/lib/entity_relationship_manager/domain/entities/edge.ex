defmodule EntityRelationshipManager.Domain.Entities.Edge do
  @moduledoc """
  Domain object representing a graph relationship (edge) in the workspace.

  An edge connects a source entity to a target entity, has a type
  (matching an EdgeTypeDefinition in the schema), properties, and
  soft-delete support via `deleted_at`.

  This is a pure domain struct with no I/O dependencies.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          type: String.t() | nil,
          source_id: String.t() | nil,
          target_id: String.t() | nil,
          properties: map(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          deleted_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :workspace_id,
    :type,
    :source_id,
    :target_id,
    :created_at,
    :updated_at,
    :deleted_at,
    properties: %{}
  ]

  @doc """
  Creates a new Edge from an atom-keyed map.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Returns true if the edge has been soft-deleted.
  """
  @spec deleted?(t()) :: boolean()
  def deleted?(%__MODULE__{deleted_at: nil}), do: false
  def deleted?(%__MODULE__{deleted_at: _}), do: true
end
