defmodule Jarga.Notes.QueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notes.Queries
  alias Jarga.Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures
  import Jarga.NotesFixtures

  describe "base/0" do
    test "returns a queryable for notes" do
      query = Queries.base()

      assert %Ecto.Query{} = query
    end
  end

  describe "for_user/2" do
    test "filters notes by user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = Jarga.Workspaces.invite_member(user1, workspace.id, user2.email, :member)

      note1 = note_fixture(user1, workspace.id)
      note2 = note_fixture(user2, workspace.id)

      results =
        Queries.base()
        |> Queries.for_user(user1)
        |> Repo.all()

      note_ids = Enum.map(results, & &1.id)
      assert note1.id in note_ids
      refute note2.id in note_ids
    end
  end

  describe "for_workspace/2" do
    test "filters notes by workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)

      note1 = note_fixture(user, workspace1.id)
      note2 = note_fixture(user, workspace2.id)

      results =
        Queries.base()
        |> Queries.for_workspace(workspace1.id)
        |> Repo.all()

      note_ids = Enum.map(results, & &1.id)
      assert note1.id in note_ids
      refute note2.id in note_ids
    end
  end

  describe "for_project/2" do
    test "filters notes by project" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace)
      project2 = project_fixture(user, workspace)

      note1 = note_fixture(user, workspace.id, %{project_id: project1.id})
      note2 = note_fixture(user, workspace.id, %{project_id: project2.id})

      results =
        Queries.base()
        |> Queries.for_project(project1.id)
        |> Repo.all()

      note_ids = Enum.map(results, & &1.id)
      assert note1.id in note_ids
      refute note2.id in note_ids
    end
  end

  describe "by_id/2" do
    test "filters notes by id" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      note1 = note_fixture(user, workspace.id)
      _note2 = note_fixture(user, workspace.id)

      result =
        Queries.base()
        |> Queries.by_id(note1.id)
        |> Repo.one()

      assert result.id == note1.id
    end

    test "returns nil when note doesn't exist" do
      fake_id = Ecto.UUID.generate()

      result =
        Queries.base()
        |> Queries.by_id(fake_id)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "ordered/1" do
    test "orders notes by inserted_at descending" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Create notes
      _note1 = note_fixture(user, workspace.id)
      _note2 = note_fixture(user, workspace.id)
      _note3 = note_fixture(user, workspace.id)

      results =
        Queries.base()
        |> Queries.for_user(user)
        |> Queries.ordered()
        |> Repo.all()

      # Verify ordering by checking timestamps are descending
      assert length(results) == 3
      timestamps = Enum.map(results, & &1.inserted_at)

      # Verify first timestamp is >= second timestamp is >= third timestamp
      [first, second, third] = timestamps
      assert DateTime.compare(first, second) in [:gt, :eq]
      assert DateTime.compare(second, third) in [:gt, :eq]
    end
  end

  describe "composable queries" do
    test "can combine multiple filters" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = Jarga.Workspaces.invite_member(user1, workspace.id, user2.email, :member)
      project = project_fixture(user1, workspace)

      # Create notes in different combinations
      note1 = note_fixture(user1, workspace.id, %{project_id: project.id})
      _note2 = note_fixture(user1, workspace.id)
      _note3 = note_fixture(user2, workspace.id, %{project_id: project.id})

      results =
        Queries.base()
        |> Queries.for_user(user1)
        |> Queries.for_workspace(workspace.id)
        |> Queries.for_project(project.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == note1.id
    end
  end
end
