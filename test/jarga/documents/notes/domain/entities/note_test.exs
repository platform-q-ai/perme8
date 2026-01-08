defmodule Jarga.Documents.Notes.Domain.Entities.NoteTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Notes.Domain.Entities.Note
  alias Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema

  describe "new/1" do
    test "creates a new note entity from attributes" do
      attrs = %{
        id: "123",
        note_content: "Hello",
        yjs_state: <<1, 2, 3>>,
        user_id: "user-1",
        workspace_id: "workspace-1",
        project_id: "project-1"
      }

      note = Note.new(attrs)

      assert note.id == "123"
      assert note.note_content == "Hello"
      assert note.yjs_state == <<1, 2, 3>>
      assert note.user_id == "user-1"
      assert note.workspace_id == "workspace-1"
      assert note.project_id == "project-1"
    end

    test "creates note with nil values for optional fields" do
      attrs = %{
        user_id: "user-1",
        workspace_id: "workspace-1"
      }

      note = Note.new(attrs)

      assert note.id == nil
      assert note.note_content == nil
      assert note.yjs_state == nil
      assert note.project_id == nil
      assert note.user_id == "user-1"
      assert note.workspace_id == "workspace-1"
    end
  end

  describe "from_schema/1" do
    test "converts a schema to a domain entity" do
      now = ~U[2024-01-01 00:00:00Z]

      schema = %NoteSchema{
        id: "123",
        note_content: "Hello",
        yjs_state: <<1, 2, 3>>,
        user_id: "user-1",
        workspace_id: "workspace-1",
        project_id: "project-1",
        inserted_at: now,
        updated_at: now
      }

      note = Note.from_schema(schema)

      assert note.id == "123"
      assert note.note_content == "Hello"
      assert note.yjs_state == <<1, 2, 3>>
      assert note.user_id == "user-1"
      assert note.workspace_id == "workspace-1"
      assert note.project_id == "project-1"
      assert note.inserted_at == now
      assert note.updated_at == now
    end

    test "handles nil values in schema" do
      schema = %NoteSchema{
        id: "123",
        note_content: nil,
        yjs_state: nil,
        user_id: "user-1",
        workspace_id: "workspace-1",
        project_id: nil,
        inserted_at: nil,
        updated_at: nil
      }

      note = Note.from_schema(schema)

      assert note.id == "123"
      assert note.note_content == nil
      assert note.yjs_state == nil
      assert note.project_id == nil
      assert note.user_id == "user-1"
      assert note.workspace_id == "workspace-1"
    end
  end
end
