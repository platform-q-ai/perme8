defmodule Jarga.Documents.Notes.Domain.Entities.Note do
  @moduledoc """
  Pure domain entity for notes.

  This is a value object representing a note in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          note_content: String.t() | nil,
          yjs_state: binary() | nil,
          user_id: String.t(),
          workspace_id: String.t(),
          project_id: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :note_content,
    :yjs_state,
    :user_id,
    :workspace_id,
    :project_id,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new Note domain entity from attributes.
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
      note_content: schema.note_content,
      yjs_state: schema.yjs_state,
      user_id: schema.user_id,
      workspace_id: schema.workspace_id,
      project_id: schema.project_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end
