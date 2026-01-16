defmodule Jarga.Documents.Application.Services.ComponentLoaderTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Domain.Entities.DocumentComponent
  alias Jarga.Documents.Application.Services.ComponentLoader
  alias Jarga.Notes

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "load_component/1 - note components" do
    test "loads note when component_type is 'note'" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()
      {:ok, note} = Notes.create_note(user, workspace.id, %{id: note_id})

      document_component = %DocumentComponent{
        component_type: "note",
        component_id: note.id
      }

      loaded_note = ComponentLoader.load_component(document_component)

      assert loaded_note.id == note.id
      assert loaded_note.note_content == note.note_content
    end

    test "returns nil when note doesn't exist" do
      non_existent_id = Ecto.UUID.generate()

      document_component = %DocumentComponent{
        component_type: "note",
        component_id: non_existent_id
      }

      assert ComponentLoader.load_component(document_component) == nil
    end

    test "loads correct note when multiple notes exist" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      note1_id = Ecto.UUID.generate()
      note2_id = Ecto.UUID.generate()

      {:ok, note1} = Notes.create_note(user, workspace.id, %{id: note1_id})
      {:ok, _note2} = Notes.create_note(user, workspace.id, %{id: note2_id})

      document_component = %DocumentComponent{
        component_type: "note",
        component_id: note1.id
      }

      loaded_note = ComponentLoader.load_component(document_component)

      assert loaded_note.id == note1.id
    end
  end

  describe "load_component/1 - task_list components (future)" do
    test "returns nil for task_list (not yet implemented)" do
      task_id = Ecto.UUID.generate()

      document_component = %DocumentComponent{
        component_type: "task_list",
        component_id: task_id
      }

      assert ComponentLoader.load_component(document_component) == nil
    end
  end

  describe "load_component/1 - sheet components (future)" do
    test "returns nil for sheet (not yet implemented)" do
      sheet_id = Ecto.UUID.generate()

      document_component = %DocumentComponent{
        component_type: "sheet",
        component_id: sheet_id
      }

      assert ComponentLoader.load_component(document_component) == nil
    end
  end

  describe "load_component/1 - unknown component types" do
    test "returns nil for unknown component type" do
      document_component = %DocumentComponent{
        component_type: "unknown_type",
        component_id: Ecto.UUID.generate()
      }

      assert ComponentLoader.load_component(document_component) == nil
    end

    test "returns nil for nil component type" do
      document_component = %DocumentComponent{
        component_type: nil,
        component_id: Ecto.UUID.generate()
      }

      assert ComponentLoader.load_component(document_component) == nil
    end

    test "returns nil for invalid document component struct" do
      assert ComponentLoader.load_component(%{}) == nil
    end

    test "returns nil for nil input" do
      assert ComponentLoader.load_component(nil) == nil
    end
  end
end
