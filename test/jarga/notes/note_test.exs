defmodule Jarga.Notes.NoteTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notes.Note

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "changeset/2" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, user: user, workspace: workspace}
    end

    test "valid changeset with required fields", %{user: user, workspace: workspace} do
      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace.id,
        note_content: %{"text" => "Test note"}
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert changeset.valid?
    end

    test "requires id", %{user: user, workspace: workspace} do
      attrs = %{
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert "can't be blank" in errors_on(changeset).id
    end

    test "requires user_id", %{workspace: workspace} do
      attrs = %{
        id: Ecto.UUID.generate(),
        workspace_id: workspace.id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires workspace_id", %{user: user} do
      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "allows optional project_id", %{user: user, workspace: workspace} do
      project = project_fixture(user, workspace)

      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace.id,
        project_id: project.id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :project_id) == project.id
    end

    test "allows optional note_content", %{user: user, workspace: workspace} do
      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert changeset.valid?
    end

    test "allows optional yjs_state", %{user: user, workspace: workspace} do
      yjs_binary = <<1, 2, 3, 4>>

      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace.id,
        yjs_state: yjs_binary
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :yjs_state) == yjs_binary
    end

    test "accepts note_content as map", %{user: user, workspace: workspace} do
      content = %{
        "text" => "Some content",
        "format" => "markdown"
      }

      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace.id,
        note_content: content
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :note_content) == content
    end

    test "validates user_id foreign key constraint on insert", %{workspace: workspace} do
      fake_user_id = Ecto.UUID.generate()

      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: fake_user_id,
        workspace_id: workspace.id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).user_id
    end

    test "validates workspace_id foreign key constraint on insert", %{user: user} do
      fake_workspace_id = Ecto.UUID.generate()

      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: fake_workspace_id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).workspace_id
    end

    test "validates project_id foreign key constraint when provided", %{
      user: user,
      workspace: workspace
    } do
      fake_project_id = Ecto.UUID.generate()

      attrs = %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace.id,
        project_id: fake_project_id
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).project_id
    end

    test "casts all fields correctly", %{user: user, workspace: workspace} do
      project = project_fixture(user, workspace)
      note_id = Ecto.UUID.generate()
      content = %{"text" => "Test"}
      yjs_state = <<1, 2, 3>>

      attrs = %{
        id: note_id,
        user_id: user.id,
        workspace_id: workspace.id,
        project_id: project.id,
        note_content: content,
        yjs_state: yjs_state
      }

      changeset = Note.changeset(%Note{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :id) == note_id
      assert Ecto.Changeset.get_change(changeset, :user_id) == user.id
      assert Ecto.Changeset.get_change(changeset, :workspace_id) == workspace.id
      assert Ecto.Changeset.get_change(changeset, :project_id) == project.id
      assert Ecto.Changeset.get_change(changeset, :note_content) == content
      assert Ecto.Changeset.get_change(changeset, :yjs_state) == yjs_state
    end
  end
end
