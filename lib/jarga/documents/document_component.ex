defmodule Jarga.Documents.DocumentComponent do
  @moduledoc """
  Join table for documents and their components (notes, tasks, sheets, etc.)
  Uses a polymorphic association pattern.

  For loading the actual component records, see `Jarga.Documents.Services.ComponentLoader`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "document_components" do
    belongs_to(:document, Jarga.Documents.Document)

    # Polymorphic association
    field(:component_type, :string)
    field(:component_id, Ecto.UUID)

    # For ordering components on the document
    field(:position, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document_component, attrs) do
    document_component
    |> cast(attrs, [:document_id, :component_type, :component_id, :position])
    |> validate_required([:document_id, :component_type, :component_id, :position])
    |> validate_inclusion(:component_type, ["note", "task_list", "sheet"])
    |> foreign_key_constraint(:document_id)
    |> unique_constraint([:document_id, :component_type, :component_id])
  end
end
