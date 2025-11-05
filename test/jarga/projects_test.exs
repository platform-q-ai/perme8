defmodule Jarga.ProjectsTest do
  use Jarga.DataCase, async: true

  alias Jarga.Projects

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  defmodule MockNotifier do
    @behaviour Jarga.Projects.Services.NotificationService

    def notify_project_created(_project), do: :ok
    def notify_project_deleted(_project, _workspace_id), do: :ok
    def notify_project_updated(_project), do: :ok
  end

  describe "list_projects_for_workspace/2" do
    test "returns empty list when workspace has no projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert Projects.list_projects_for_workspace(user, workspace.id) == []
    end

    test "returns only projects for the given workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "Workspace 1"})
      workspace2 = workspace_fixture(user, %{name: "Workspace 2"})

      project1 = project_fixture(user, workspace1, %{name: "Project 1"})
      _project2 = project_fixture(user, workspace2, %{name: "Project 2"})

      projects = Projects.list_projects_for_workspace(user, workspace1.id)

      assert length(projects) == 1
      assert hd(projects).id == project1.id
    end

    test "returns multiple projects for workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      project1 = project_fixture(user, workspace, %{name: "Project 1"})
      project2 = project_fixture(user, workspace, %{name: "Project 2"})

      projects = Projects.list_projects_for_workspace(user, workspace.id)

      assert length(projects) == 2
      project_ids = Enum.map(projects, & &1.id)
      assert project1.id in project_ids
      assert project2.id in project_ids
    end

    test "does not return archived projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      _active_project = project_fixture(user, workspace, %{name: "Active"})
      _archived_project = project_fixture(user, workspace, %{name: "Archived", is_archived: true})

      projects = Projects.list_projects_for_workspace(user, workspace.id)

      assert length(projects) == 1
      assert hd(projects).name == "Active"
    end

    test "only returns projects from workspaces user is member of" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      _project = project_fixture(other_user, workspace)

      # User should not be able to see projects from workspaces they're not a member of
      assert Projects.list_projects_for_workspace(user, workspace.id) == []
    end
  end

  describe "create_project/3" do
    test "creates project with valid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        name: "My Project",
        description: "A test project",
        color: "#FF5733"
      }

      assert {:ok, project} = Projects.create_project(user, workspace.id, attrs)
      assert project.name == "My Project"
      assert project.description == "A test project"
      assert project.color == "#FF5733"
      assert project.workspace_id == workspace.id
      assert project.user_id == user.id
      assert project.is_archived == false
      assert project.is_default == false
    end

    test "creates project with minimal attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{name: "Minimal Project"}

      assert {:ok, project} = Projects.create_project(user, workspace.id, attrs)
      assert project.name == "Minimal Project"
      assert project.description == nil
      assert project.color == nil
    end

    test "returns error for missing name" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{description: "No name provided"}

      assert {:error, changeset} = Projects.create_project(user, workspace.id, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error for empty name" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{name: ""}

      assert {:error, changeset} = Projects.create_project(user, workspace.id, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      attrs = %{name: "Unauthorized Project"}

      assert {:error, :unauthorized} = Projects.create_project(user, workspace.id, attrs)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      attrs = %{name: "Project"}

      assert {:error, :workspace_not_found} =
               Projects.create_project(user, Ecto.UUID.generate(), attrs)
    end

    test "uses mock notifier when provided via opts" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{name: "Mock Notifier Test"}

      # Pass MockNotifier via opts to avoid real broadcast
      assert {:ok, project} =
               Projects.create_project(user, workspace.id, attrs, notifier: MockNotifier)

      assert project.name == "Mock Notifier Test"
    end

    # Integration test: verifies default notifier broadcasts to PubSub
    test "broadcasts project_added message to workspace topic on success (integration)" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Subscribe to the workspace topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

      attrs = %{name: "Broadcast Test Project"}

      assert {:ok, project} = Projects.create_project(user, workspace.id, attrs)

      # Verify the broadcast was sent
      assert_receive {:project_added, project_id}
      assert project_id == project.id
    end

    # Integration test: verifies no broadcast on failure
    test "does not broadcast when project creation fails (integration)" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Subscribe to the workspace topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

      attrs = %{name: ""}

      assert {:error, _changeset} = Projects.create_project(user, workspace.id, attrs)

      # Verify no broadcast was sent
      refute_receive {:project_added, _}, 100
    end
  end

  describe "get_project!/3" do
    test "returns project when user is member of workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert fetched = Projects.get_project!(user, workspace.id, project.id)
      assert fetched.id == project.id
      assert fetched.name == project.name
    end

    test "raises when project doesn't exist" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(user, workspace.id, Ecto.UUID.generate())
      end
    end

    test "raises when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      project = project_fixture(other_user, workspace)

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(user, workspace.id, project.id)
      end
    end

    test "raises when project belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(user, workspace1.id, project.id)
      end
    end
  end

  describe "update_project/4" do
    test "updates project with valid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace, %{name: "Original Name"})

      attrs = %{name: "Updated Name", description: "Updated description"}

      assert {:ok, updated_project} =
               Projects.update_project(user, workspace.id, project.id, attrs)

      assert updated_project.name == "Updated Name"
      assert updated_project.description == "Updated description"
      assert updated_project.id == project.id
    end

    test "updates project with partial attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      project =
        project_fixture(user, workspace, %{name: "Original", description: "Original desc"})

      attrs = %{name: "New Name"}

      assert {:ok, updated_project} =
               Projects.update_project(user, workspace.id, project.id, attrs)

      assert updated_project.name == "New Name"
      assert updated_project.description == "Original desc"
    end

    test "returns error for invalid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      attrs = %{name: ""}

      assert {:error, changeset} = Projects.update_project(user, workspace.id, project.id, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      project = project_fixture(other_user, workspace)

      attrs = %{name: "Updated Name"}

      assert {:error, :unauthorized} =
               Projects.update_project(user, workspace.id, project.id, attrs)
    end

    test "returns error when project doesn't exist" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{name: "Updated Name"}

      assert {:error, :project_not_found} =
               Projects.update_project(user, workspace.id, Ecto.UUID.generate(), attrs)
    end

    test "returns error when project belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      attrs = %{name: "Updated Name"}

      assert {:error, :project_not_found} =
               Projects.update_project(user, workspace1.id, project.id, attrs)
    end
  end

  describe "delete_project/3" do
    test "deletes project when user is workspace member" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:ok, deleted_project} = Projects.delete_project(user, workspace.id, project.id)
      assert deleted_project.id == project.id

      # Verify project is deleted
      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project!(user, workspace.id, project.id)
      end
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      project = project_fixture(other_user, workspace)

      assert {:error, :unauthorized} = Projects.delete_project(user, workspace.id, project.id)
    end

    test "returns error when project doesn't exist" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:error, :project_not_found} =
               Projects.delete_project(user, workspace.id, Ecto.UUID.generate())
    end

    test "returns error when project belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      assert {:error, :project_not_found} =
               Projects.delete_project(user, workspace1.id, project.id)
    end

    test "uses mock notifier when provided via opts" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      # Pass MockNotifier via opts to avoid real broadcast
      assert {:ok, deleted_project} =
               Projects.delete_project(user, workspace.id, project.id, notifier: MockNotifier)

      assert deleted_project.id == project.id
    end

    # Integration test: verifies default notifier broadcasts to PubSub
    test "broadcasts project_removed message to workspace topic on success (integration)" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      # Subscribe to the workspace topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

      assert {:ok, deleted_project} = Projects.delete_project(user, workspace.id, project.id)

      # Verify the broadcast was sent
      assert_receive {:project_removed, project_id}
      assert project_id == deleted_project.id
    end

    # Integration test: verifies no broadcast on failure
    test "does not broadcast when project deletion fails (integration)" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Subscribe to the workspace topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

      assert {:error, :project_not_found} =
               Projects.delete_project(user, workspace.id, Ecto.UUID.generate())

      # Verify no broadcast was sent
      refute_receive {:project_removed, _}, 100
    end
  end

  describe "project slugs" do
    test "generates slug from name on create" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{name: "My Awesome Project"}

      assert {:ok, project} = Projects.create_project(user, workspace.id, attrs)
      assert project.slug == "my-awesome-project"
    end

    test "generates slug with special characters removed" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{name: "My Project! @#$%"}

      assert {:ok, project} = Projects.create_project(user, workspace.id, attrs)
      assert project.slug == "my-project"
    end

    test "generates slug with consecutive spaces normalized" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{name: "My    Multiple   Spaces"}

      assert {:ok, project} = Projects.create_project(user, workspace.id, attrs)
      assert project.slug == "my-multiple-spaces"
    end

    test "handles slug collisions within same workspace by appending random suffix" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{name: "Duplicate Name"}

      assert {:ok, project1} = Projects.create_project(user, workspace.id, attrs)
      assert project1.slug == "duplicate-name"

      assert {:ok, project2} = Projects.create_project(user, workspace.id, attrs)
      # Should have random suffix appended
      assert project2.slug =~ ~r/^duplicate-name-[a-z0-9]+$/
      assert project2.slug != project1.slug
    end

    test "allows same slug in different workspaces" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "Workspace 1"})
      workspace2 = workspace_fixture(user, %{name: "Workspace 2"})
      attrs = %{name: "Same Name"}

      assert {:ok, project1} = Projects.create_project(user, workspace1.id, attrs)
      assert project1.slug == "same-name"

      assert {:ok, project2} = Projects.create_project(user, workspace2.id, attrs)
      # Should have same slug since they're in different workspaces
      assert project2.slug == "same-name"
    end

    test "keeps slug stable when name changes" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace, %{name: "Original Name"})

      assert project.slug == "original-name"

      assert {:ok, updated_project} =
               Projects.update_project(user, workspace.id, project.id, %{name: "New Name"})

      assert updated_project.slug == "original-name"
      assert updated_project.name == "New Name"
    end

    test "keeps original slug when updating name to existing name" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace, %{name: "First Project"})
      project2 = project_fixture(user, workspace, %{name: "Second Project"})

      assert project1.slug == "first-project"
      assert project2.slug == "second-project"

      # Update project2 to have same name as project1
      assert {:ok, updated} =
               Projects.update_project(user, workspace.id, project2.id, %{name: "First Project"})

      # Slug should remain unchanged
      assert updated.slug == "second-project"
      assert updated.name == "First Project"
    end
  end

  describe "get_project_by_slug!/3" do
    test "returns project when user is member and slug matches" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace, %{name: "My Project"})

      assert fetched = Projects.get_project_by_slug!(user, workspace.id, "my-project")
      assert fetched.id == project.id
      assert fetched.name == project.name
    end

    test "raises when project doesn't exist with that slug" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project_by_slug!(user, workspace.id, "nonexistent")
      end
    end

    test "raises when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)
      _project = project_fixture(other_user, workspace, %{name: "Other Project"})

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project_by_slug!(user, workspace.id, "other-project")
      end
    end

    test "raises when project with slug belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      _project = project_fixture(user, workspace2, %{name: "Project"})

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project_by_slug!(user, workspace1.id, "project")
      end
    end
  end
end
