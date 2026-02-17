defmodule KnowledgeMcp.Domain.Entities.KnowledgeRelationship do
  @moduledoc """
  Pure domain entity representing a relationship between knowledge entries.

  Wraps ERM Edge properties for the knowledge domain.
  This is a pure struct with no I/O dependencies.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          from_id: String.t() | nil,
          to_id: String.t() | nil,
          type: String.t() | nil,
          created_at: DateTime.t() | nil
        }

  defstruct [:id, :from_id, :to_id, :type, :created_at]

  @doc """
  Creates a new KnowledgeRelationship from an atom-keyed map.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an ERM Edge into a KnowledgeRelationship.
  """
  @spec from_erm_edge(map()) :: t()
  def from_erm_edge(%{source_id: source_id, target_id: target_id} = edge) do
    %__MODULE__{
      id: edge.id,
      from_id: source_id,
      to_id: target_id,
      type: edge.type,
      created_at: edge.created_at
    }
  end
end
