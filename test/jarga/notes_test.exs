defmodule Jarga.NotesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notes

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "get_note!/2" do
    test "returns note when it exists and belongs to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      {:ok, note} =
        Notes.create_note(user, workspace.id, %{
          id: note_id,
          note_content: "# Test Note"
        })

      assert fetched = Notes.get_note!(user, note_id)
      assert fetched.id == note.id
      assert fetched.user_id == user.id
    end

    test "raises when note doesn't exist" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Notes.get_note!(user, Ecto.UUID.generate())
      end
    end

    test "raises when note belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      note_id = Ecto.UUID.generate()

      {:ok, note} =
        Notes.create_note(user1, workspace.id, %{
          id: note_id,
          note_content: "Test content"
        })

      assert_raise Ecto.NoResultsError, fn ->
        Notes.get_note!(user2, note.id)
      end
    end
  end

  describe "create_note/3" do
    test "creates note with valid attributes in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      note_content = "# Test Note\n\nSome content"

      attrs = %{
        id: note_id,
        note_content: note_content,
        yjs_state: <<1, 2, 3>>
      }

      assert {:ok, note} = Notes.create_note(user, workspace.id, attrs)
      assert note.id == note_id
      assert note.user_id == user.id
      assert note.workspace_id == workspace.id
      assert note.project_id == nil
      assert note.note_content == note_content
      assert note.yjs_state == <<1, 2, 3>>
    end

    test "creates note with valid attributes in project" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)
      note_id = Ecto.UUID.generate()

      attrs = %{
        id: note_id,
        note_content: "Test content",
        project_id: project.id
      }

      assert {:ok, note} = Notes.create_note(user, workspace.id, attrs)
      assert note.project_id == project.id
    end

    test "creates note with minimal attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      attrs = %{id: note_id}

      assert {:ok, note} = Notes.create_note(user, workspace.id, attrs)
      assert note.id == note_id
      assert note.note_content == nil
      assert note.yjs_state == nil
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      note_id = Ecto.UUID.generate()

      attrs = %{id: note_id, note_content: "Test content"}

      assert {:error, :unauthorized} = Notes.create_note(user, workspace.id, attrs)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()
      note_id = Ecto.UUID.generate()

      attrs = %{id: note_id, note_content: "Test content"}

      assert {:error, :workspace_not_found} = Notes.create_note(user, Ecto.UUID.generate(), attrs)
    end

    test "returns error when project does not belong to workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)
      note_id = Ecto.UUID.generate()

      attrs = %{
        id: note_id,
        note_content: %{"type" => "doc"},
        project_id: project.id
      }

      assert {:error, :invalid_project} = Notes.create_note(user, workspace1.id, attrs)
    end
  end

  describe "update_note/3" do
    test "updates note content" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      {:ok, note} =
        Notes.create_note(user, workspace.id, %{
          id: note_id,
          note_content: "Initial content"
        })

      new_content = "Updated content"
      attrs = %{note_content: new_content}

      assert {:ok, updated} = Notes.update_note(user, note.id, attrs)
      assert updated.note_content == new_content
      assert updated.id == note.id
    end

    test "updates yjs_state" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      {:ok, note} =
        Notes.create_note(user, workspace.id, %{
          id: note_id,
          yjs_state: <<1, 2, 3>>
        })

      new_yjs_state = <<4, 5, 6, 7>>
      attrs = %{yjs_state: new_yjs_state}

      assert {:ok, updated} = Notes.update_note(user, note.id, attrs)
      assert updated.yjs_state == new_yjs_state
    end

    test "updates both content and yjs_state" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      {:ok, note} = Notes.create_note(user, workspace.id, %{id: note_id})

      attrs = %{
        note_content: "Updated content",
        yjs_state: <<10, 20, 30>>
      }

      assert {:ok, updated} = Notes.update_note(user, note.id, attrs)
      assert updated.note_content == "Updated content"
      assert updated.yjs_state == <<10, 20, 30>>
    end

    test "returns error when note doesn't exist" do
      user = user_fixture()

      attrs = %{note_content: %{"type" => "doc"}}

      assert {:error, :note_not_found} = Notes.update_note(user, Ecto.UUID.generate(), attrs)
    end

    test "returns error when note belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      note_id = Ecto.UUID.generate()

      {:ok, note} = Notes.create_note(user1, workspace.id, %{id: note_id})

      attrs = %{note_content: %{"type" => "doc", "malicious" => true}}

      assert {:error, :unauthorized} = Notes.update_note(user2, note.id, attrs)
    end
  end

  describe "delete_note/2" do
    test "deletes note when it belongs to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note_id = Ecto.UUID.generate()

      {:ok, note} = Notes.create_note(user, workspace.id, %{id: note_id})

      assert {:ok, deleted} = Notes.delete_note(user, note.id)
      assert deleted.id == note.id

      # Verify note is deleted
      assert_raise Ecto.NoResultsError, fn ->
        Notes.get_note!(user, note.id)
      end
    end

    test "returns error when note doesn't exist" do
      user = user_fixture()

      assert {:error, :note_not_found} = Notes.delete_note(user, Ecto.UUID.generate())
    end

    test "returns error when note belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      note_id = Ecto.UUID.generate()

      {:ok, note} = Notes.create_note(user1, workspace.id, %{id: note_id})

      assert {:error, :unauthorized} = Notes.delete_note(user2, note.id)
    end
  end

  describe "list_notes_for_workspace/2" do
    test "returns empty list when workspace has no notes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert Notes.list_notes_for_workspace(user, workspace.id) == []
    end

    test "returns all notes for workspace belonging to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note1_id = Ecto.UUID.generate()
      note2_id = Ecto.UUID.generate()

      {:ok, note1} = Notes.create_note(user, workspace.id, %{id: note1_id})
      {:ok, note2} = Notes.create_note(user, workspace.id, %{id: note2_id})

      notes = Notes.list_notes_for_workspace(user, workspace.id)

      assert length(notes) == 2
      note_ids = Enum.map(notes, & &1.id)
      assert note1.id in note_ids
      assert note2.id in note_ids
    end

    test "does not return notes from other workspaces" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      note1_id = Ecto.UUID.generate()
      note2_id = Ecto.UUID.generate()

      {:ok, note1} = Notes.create_note(user, workspace1.id, %{id: note1_id})
      {:ok, _note2} = Notes.create_note(user, workspace2.id, %{id: note2_id})

      notes = Notes.list_notes_for_workspace(user, workspace1.id)

      assert length(notes) == 1
      assert hd(notes).id == note1.id
    end

    test "does not return notes from other users even in same workspace" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace1 = workspace_fixture(user1)
      workspace2 = workspace_fixture(user2)

      note1_id = Ecto.UUID.generate()
      note2_id = Ecto.UUID.generate()

      {:ok, note1} = Notes.create_note(user1, workspace1.id, %{id: note1_id})
      {:ok, note2} = Notes.create_note(user2, workspace2.id, %{id: note2_id})

      # Each user should only see their own notes
      notes_user1 = Notes.list_notes_for_workspace(user1, workspace1.id)
      notes_user2 = Notes.list_notes_for_workspace(user2, workspace2.id)

      assert length(notes_user1) == 1
      assert hd(notes_user1).id == note1.id

      assert length(notes_user2) == 1
      assert hd(notes_user2).id == note2.id
    end
  end

  describe "list_notes_for_project/3" do
    test "returns empty list when project has no notes" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert Notes.list_notes_for_project(user, workspace.id, project.id) == []
    end

    test "returns all notes for project belonging to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)
      note1_id = Ecto.UUID.generate()
      note2_id = Ecto.UUID.generate()

      {:ok, note1} =
        Notes.create_note(user, workspace.id, %{
          id: note1_id,
          project_id: project.id
        })

      {:ok, note2} =
        Notes.create_note(user, workspace.id, %{
          id: note2_id,
          project_id: project.id
        })

      notes = Notes.list_notes_for_project(user, workspace.id, project.id)

      assert length(notes) == 2
      note_ids = Enum.map(notes, & &1.id)
      assert note1.id in note_ids
      assert note2.id in note_ids
    end

    test "does not return notes from other projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace)
      project2 = project_fixture(user, workspace)
      note1_id = Ecto.UUID.generate()
      note2_id = Ecto.UUID.generate()

      {:ok, note1} =
        Notes.create_note(user, workspace.id, %{
          id: note1_id,
          project_id: project1.id
        })

      {:ok, _note2} =
        Notes.create_note(user, workspace.id, %{
          id: note2_id,
          project_id: project2.id
        })

      notes = Notes.list_notes_for_project(user, workspace.id, project1.id)

      assert length(notes) == 1
      assert hd(notes).id == note1.id
    end
  end
end
