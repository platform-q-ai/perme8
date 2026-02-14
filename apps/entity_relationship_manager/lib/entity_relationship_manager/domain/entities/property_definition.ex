defmodule EntityRelationshipManager.Domain.Entities.PropertyDefinition do
  @moduledoc """
  Value object representing a property definition within an entity or edge type.

  Defines the name, type, whether it's required, and any constraints for a
  property in the schema. This is a pure domain struct with no I/O dependencies.

  ## Valid Types

  - `:string` - Text values
  - `:integer` - Whole numbers
  - `:float` - Decimal numbers
  - `:boolean` - True/false values
  - `:datetime` - ISO8601 datetime strings
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          type: atom() | nil,
          required: boolean(),
          constraints: map()
        }

  defstruct [:name, :type, required: false, constraints: %{}]

  @valid_types ~w(string integer float boolean datetime)a

  @doc """
  Creates a new PropertyDefinition from an atom-keyed map.

  ## Examples

      iex> PropertyDefinition.new(%{name: "email", type: :string, required: true})
      %PropertyDefinition{name: "email", type: :string, required: true, constraints: %{}}
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Deserializes a PropertyDefinition from a string-keyed map (e.g., from JSONB).

  Converts the `"type"` string to an atom from the valid types list.

  ## Examples

      iex> PropertyDefinition.from_map(%{"name" => "email", "type" => "string"})
      %PropertyDefinition{name: "email", type: :string, required: false, constraints: %{}}
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      name: Map.get(map, "name"),
      type: parse_type(Map.get(map, "type")),
      required: Map.get(map, "required", false),
      constraints: Map.get(map, "constraints", %{})
    }
  end

  @doc """
  Returns the list of valid property types.
  """
  @spec valid_types() :: [atom()]
  def valid_types, do: @valid_types

  defp parse_type(nil), do: nil

  defp parse_type(type) when is_binary(type) do
    atom = String.to_atom(type)
    if atom in @valid_types, do: atom, else: nil
  end

  defp parse_type(type) when is_atom(type), do: type
end
