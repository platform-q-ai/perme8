defmodule Jarga.Documents.Infrastructure.Services.ComponentLoader do
  @moduledoc """
  Service for loading polymorphic document components.

  Handles loading the actual component records (notes, task lists, sheets, etc.)
  based on the polymorphic association in DocumentComponent.

  This logic was moved from the DocumentComponent schema to follow Clean Architecture
  and SOLID principles - schemas should only handle data mapping, not business logic.

  ## Status

  This module is currently tested but not actively used in production code.
  It was created in preparation for features that load and display document components
  polymorphically. When implementing features that need to fetch the actual component
  records (e.g., rendering a document with all its embedded notes/tasks/sheets), use
  this service instead of implementing component loading logic inline.

  ## Future Use Cases

  - Document rendering with all embedded components
  - Component search across documents
  - Component migration/copying between documents
  """

  alias Jarga.Documents.Domain.Entities.DocumentComponent
  alias Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema
  alias Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository

  @doc """
  Loads the actual component record based on the polymorphic type.

  Accepts both domain entities and infrastructure schemas.

  ## Examples

      iex> load_component(%DocumentComponent{component_type: "note", component_id: note_id})
      %Note{}

      iex> load_component(%DocumentComponentSchema{component_type: "note", component_id: note_id})
      %Note{}

      iex> load_component(%DocumentComponent{component_type: "task_list", component_id: task_id})
      nil  # Future implementation

  """
  def load_component(%DocumentComponentSchema{component_type: "note", component_id: id}) do
    NoteRepository.get_by_id(id)
  end

  def load_component(%DocumentComponentSchema{component_type: "task_list", component_id: _id}) do
    # Future: Repo.get(Jarga.TaskLists.TaskList, _id)
    nil
  end

  def load_component(%DocumentComponentSchema{component_type: "sheet", component_id: _id}) do
    # Future: Repo.get(Jarga.Sheets.Sheet, _id)
    nil
  end

  def load_component(%DocumentComponent{component_type: "note", component_id: id}) do
    NoteRepository.get_by_id(id)
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
