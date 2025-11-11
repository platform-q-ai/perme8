defmodule Jarga.Documents.Services.ComponentLoader do
  @moduledoc """
  Service for loading polymorphic document components.

  Handles loading the actual component records (notes, task lists, sheets, etc.)
  based on the polymorphic association in DocumentComponent.

  This logic was moved from the DocumentComponent schema to follow Clean Architecture
  and SOLID principles - schemas should only handle data mapping, not business logic.
  """

  alias Jarga.Notes
  alias Jarga.Documents.DocumentComponent

  @doc """
  Loads the actual component record based on the polymorphic type.

  ## Examples

      iex> load_component(%DocumentComponent{component_type: "note", component_id: note_id})
      %Note{}

      iex> load_component(%DocumentComponent{component_type: "task_list", component_id: task_id})
      nil  # Future implementation

  """
  def load_component(%DocumentComponent{component_type: "note", component_id: id}) do
    Notes.get_note_by_id(id)
  end

  def load_component(%DocumentComponent{component_type: "task_list", component_id: _id}) do
    # Future: Repo.get(Jarga.TaskLists.TaskList, _id)
    nil
  end

  def load_component(%DocumentComponent{component_type: "sheet", component_id: _id}) do
    # Future: Repo.get(Jarga.Sheets.Sheet, _id)
    nil
  end

  def load_component(_), do: nil
end
