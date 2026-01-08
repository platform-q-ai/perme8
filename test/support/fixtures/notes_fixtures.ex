defmodule Jarga.NotesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Notes` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary, top_level?: true, deps: [Jarga.Notes], exports: []

  alias Jarga.Notes

  def valid_note_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: Ecto.UUID.generate(),
      note_content: ""
    })
  end

  def note_fixture(user, workspace_id, attrs \\ %{}) do
    attrs = valid_note_attributes(attrs)
    {:ok, note} = Notes.create_note(user, workspace_id, attrs)
    note
  end
end
