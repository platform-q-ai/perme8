defmodule Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Notes.Infrastructure.Repositories.NoteRepository

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.NotesFixtures

  describe "update/2" do
    test "updates note content successfully" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id, %{note_content: "original content"})

      assert {:ok, updated_note} =
               NoteRepository.update(note, %{note_content: "updated content"})

      assert updated_note.note_content == "updated content"
      assert updated_note.id == note.id
    end

    test "updates note with nil content" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id, %{note_content: "some content"})

      assert {:ok, updated_note} = NoteRepository.update(note, %{note_content: nil})
      assert updated_note.note_content == nil
    end

    test "no-op update with empty attrs returns ok" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id, %{note_content: "keep this"})

      assert {:ok, updated_note} = NoteRepository.update(note, %{})
      assert updated_note.note_content == "keep this"
    end

    test "persists updated content to database" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id, %{note_content: "before"})

      {:ok, _updated} = NoteRepository.update(note, %{note_content: "after"})

      reloaded = NoteRepository.get_by_id(note.id)
      assert reloaded.note_content == "after"
    end
  end
end
