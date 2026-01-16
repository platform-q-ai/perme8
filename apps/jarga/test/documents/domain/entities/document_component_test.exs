defmodule Jarga.Documents.Domain.Entities.DocumentComponentTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Entities.DocumentComponent

  describe "new/1" do
    test "creates a document component with given attributes" do
      attrs = %{
        id: "comp-123",
        document_id: "doc-456",
        component_type: "note",
        component_id: "note-789",
        position: 1
      }

      component = DocumentComponent.new(attrs)

      assert component.id == "comp-123"
      assert component.document_id == "doc-456"
      assert component.component_type == "note"
      assert component.component_id == "note-789"
      assert component.position == 1
    end

    test "sets default position to 0" do
      attrs = %{
        document_id: "doc-1",
        component_type: "note",
        component_id: "note-1"
      }

      component = DocumentComponent.new(attrs)

      assert component.position == 0
    end

    test "creates component with different types" do
      note_attrs = %{
        document_id: "doc-1",
        component_type: "note",
        component_id: "note-1"
      }

      task_attrs = %{
        document_id: "doc-1",
        component_type: "task_list",
        component_id: "task-1"
      }

      sheet_attrs = %{
        document_id: "doc-1",
        component_type: "sheet",
        component_id: "sheet-1"
      }

      note = DocumentComponent.new(note_attrs)
      task = DocumentComponent.new(task_attrs)
      sheet = DocumentComponent.new(sheet_attrs)

      assert note.component_type == "note"
      assert task.component_type == "task_list"
      assert sheet.component_type == "sheet"
    end
  end

  describe "from_schema/1" do
    test "converts a schema to a domain entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "comp-123",
        document_id: "doc-456",
        component_type: "note",
        component_id: "note-789",
        position: 2,
        inserted_at: ~U[2025-01-01 00:00:00Z],
        updated_at: ~U[2025-01-01 00:00:00Z]
      }

      component = DocumentComponent.from_schema(schema)

      assert %DocumentComponent{} = component
      assert component.id == "comp-123"
      assert component.document_id == "doc-456"
      assert component.component_type == "note"
      assert component.component_id == "note-789"
      assert component.position == 2
      assert component.inserted_at == ~U[2025-01-01 00:00:00Z]
      assert component.updated_at == ~U[2025-01-01 00:00:00Z]
    end

    test "preserves all component types during conversion" do
      schema = %{
        __struct__: SomeSchema,
        id: "comp-1",
        document_id: "doc-1",
        component_type: "task_list",
        component_id: "task-1",
        position: 0,
        inserted_at: ~U[2025-01-01 00:00:00Z],
        updated_at: ~U[2025-01-01 00:00:00Z]
      }

      component = DocumentComponent.from_schema(schema)

      assert component.component_type == "task_list"
    end
  end
end
