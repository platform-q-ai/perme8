defmodule Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema do
  @moduledoc """
  Ecto schema for document components.
  This is the infrastructure representation that handles database persistence for
  the join table between documents and their components (notes, tasks, sheets, etc.).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "document_components" do
    belongs_to(:document, Jarga.Documents.Infrastructure.Schemas.DocumentSchema)

    # Polymorphic association
    field(:component_type, :string)
    field(:component_id, Ecto.UUID)

    # For ordering components on the document
    field(:position, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating and updating document components.
  Accepts either a schema struct or a domain entity (which will be converted).
  """
  def changeset(document_component, attrs) do
    schema = to_schema(document_component)

    schema
    |> cast(attrs, [:document_id, :component_type, :component_id, :position])
    |> validate_required([:document_id, :component_type, :component_id, :position])
    |> validate_inclusion(:component_type, ["note", "task_list", "sheet"])
    |> foreign_key_constraint(:document_id)
    |> unique_constraint([:document_id, :component_type, :component_id])
  end

  @doc """
  Converts a domain entity to a schema struct.
  If already a schema, returns it unchanged.
  """
  def to_schema(%__MODULE__{} = schema), do: schema

  def to_schema(%{__struct__: _} = domain_entity) do
    %__MODULE__{
      id: domain_entity.id,
      document_id: domain_entity.document_id,
      component_type: domain_entity.component_type,
      component_id: domain_entity.component_id,
      position: domain_entity.position,
      inserted_at: domain_entity.inserted_at,
      updated_at: domain_entity.updated_at
    }
  end
end
