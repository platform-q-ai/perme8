defmodule Jarga.Documents.Domain.Entities.DocumentComponent do
  @moduledoc """
  Pure domain entity for document components.

  Represents the relationship between documents and their components (notes, tasks, sheets, etc.)
  using a polymorphic association pattern.

  This is a value object with no infrastructure dependencies.
  For database persistence, see Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          document_id: String.t(),
          component_type: String.t(),
          component_id: String.t(),
          position: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :document_id,
    :component_type,
    :component_id,
    :inserted_at,
    :updated_at,
    position: 0
  ]

  @doc """
  Creates a new DocumentComponent domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      document_id: schema.document_id,
      component_type: schema.component_type,
      component_id: schema.component_id,
      position: schema.position,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
