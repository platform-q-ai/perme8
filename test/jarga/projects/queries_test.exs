defmodule Jarga.Projects.QueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Projects.Queries

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "for_workspace/2" do
    test "filters projects in specific workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project1 = project_fixture(user, workspace1)
      _project2 = project_fixture(user, workspace2)

      result =
        Queries.base()
        |> Queries.for_workspace(workspace1.id)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == project1.id
    end
  end

  describe "for_user/2" do
    test "filters projects accessible by user" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      result =
        Queries.base()
        |> Queries.for_user(user)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == project.id
    end

    test "does not return projects from workspaces user is not member of" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      _project = project_fixture(user1, workspace)

      result =
        Queries.base()
        |> Queries.for_user(user2)
        |> Repo.all()

      assert result == []
    end
  end

  describe "active/1" do
    test "filters to only active projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      active_project = project_fixture(user, workspace)

      result =
        Queries.base()
        |> Queries.active()
        |> Queries.for_user(user)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == active_project.id
    end
  end

  describe "ordered/1" do
    test "orders projects by insertion time" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace, %{name: "First"})
      project2 = project_fixture(user, workspace, %{name: "Second"})

      # Update inserted_at to ensure ordering
      Repo.update_all(
        from(p in Jarga.Projects.Project, where: p.id == ^project1.id),
        set: [inserted_at: ~U[2025-01-01 10:00:00Z]]
      )

      Repo.update_all(
        from(p in Jarga.Projects.Project, where: p.id == ^project2.id),
        set: [inserted_at: ~U[2025-01-02 10:00:00Z]]
      )

      result =
        Queries.base()
        |> Queries.for_user(user)
        |> Queries.ordered()
        |> Repo.all()

      assert length(result) == 2
      # Newest first
      assert hd(result).id == project2.id
    end
  end

  describe "for_user_by_id/3" do
    test "finds project by ID for user in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      result =
        Queries.for_user_by_id(user, workspace.id, project.id)
        |> Repo.one()

      assert result.id == project.id
    end

    test "returns nil when user is not a member of workspace" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      project = project_fixture(user1, workspace)

      result =
        Queries.for_user_by_id(user2, workspace.id, project.id)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "for_user_by_slug/3" do
    test "finds project by slug for user in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      result =
        Queries.for_user_by_slug(user, workspace.id, project.slug)
        |> Repo.one()

      assert result.id == project.id
    end
  end
end
