defmodule Jarga.Pages.PageComponent do
  @moduledoc """
  Join table for pages and their components (notes, tasks, sheets, etc.)
  Uses a polymorphic association pattern.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "page_components" do
    belongs_to(:page, Jarga.Pages.Page)

    # Polymorphic association
    field(:component_type, :string)
    field(:component_id, Ecto.UUID)

    # For ordering components on the page
    field(:position, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page_component, attrs) do
    page_component
    |> cast(attrs, [:page_id, :component_type, :component_id, :position])
    |> validate_required([:page_id, :component_type, :component_id, :position])
    |> validate_inclusion(:component_type, ["note", "task_list", "sheet"])
    |> foreign_key_constraint(:page_id)
    |> unique_constraint([:page_id, :component_type, :component_id])
  end

  @doc """
  Get the actual component record based on the polymorphic type.
  """
  def get_component(%__MODULE__{component_type: "note", component_id: id}) do
    Jarga.Repo.get(Jarga.Notes.Note, id)
  end

  def get_component(%__MODULE__{component_type: "task_list", component_id: _id}) do
    # Future: Jarga.Repo.get(Jarga.TaskLists.TaskList, _id)
    nil
  end

  def get_component(%__MODULE__{component_type: "sheet", component_id: _id}) do
    # Future: Jarga.Repo.get(Jarga.Sheets.Sheet, _id)
    nil
  end
end
