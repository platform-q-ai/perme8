defmodule EntityRelationshipManager.Domain.Entities.EdgeTypeDefinition do
  @moduledoc """
  Value object representing an edge type definition within a schema.

  Defines the name and property definitions for a type of edge (graph relationship)
  in the workspace schema. This is a pure domain struct with no I/O dependencies.
  """

  alias EntityRelationshipManager.Domain.Entities.PropertyDefinition

  @type t :: %__MODULE__{
          name: String.t() | nil,
          properties: [PropertyDefinition.t()]
        }

  defstruct [:name, properties: []]

  @doc """
  Creates a new EdgeTypeDefinition from an atom-keyed map.

  ## Examples

      iex> EdgeTypeDefinition.new(%{name: "FOLLOWS", properties: [%PropertyDefinition{name: "weight", type: :float}]})
      %EdgeTypeDefinition{name: "FOLLOWS", properties: [%PropertyDefinition{...}]}
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Deserializes an EdgeTypeDefinition from a string-keyed map (e.g., from JSONB).

  Nested properties are deserialized into `PropertyDefinition` structs.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    properties =
      map
      |> Map.get("properties", [])
      |> Enum.map(&PropertyDefinition.from_map/1)

    %__MODULE__{
      name: Map.get(map, "name"),
      properties: properties
    }
  end
end
