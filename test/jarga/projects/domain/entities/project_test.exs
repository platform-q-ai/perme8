defmodule Jarga.Projects.ProjectTest do
  use Jarga.DataCase, async: true

  alias Jarga.Projects.Infrastructure.Schemas.ProjectSchema

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "changeset/2" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, user: user, workspace: workspace}
    end

    test "valid changeset with required fields", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Test Project",
        slug: "test-project",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert changeset.valid?
    end

    test "requires name", %{user: user, workspace: workspace} do
      attrs = %{
        slug: "test-project",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires slug", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Test Project",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).slug
    end

    test "requires user_id", %{workspace: workspace} do
      attrs = %{
        name: "Test Project",
        slug: "test-project",
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires workspace_id", %{user: user} do
      attrs = %{
        name: "Test Project",
        slug: "test-project",
        user_id: user.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "validates name minimum length", %{user: user, workspace: workspace} do
      attrs = %{
        name: "",
        slug: "test-project",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "allows optional description", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Test Project",
        slug: "test-project",
        description: "A test project description",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :description) == "A test project description"
    end

    test "allows optional color", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Test Project",
        slug: "test-project",
        color: "#10B981",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :color) == "#10B981"
    end

    test "allows optional is_default flag", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Default Project",
        slug: "default-project",
        is_default: true,
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :is_default) == true
    end

    test "defaults is_default to false" do
      project = %ProjectSchema{}
      assert project.is_default == false
    end

    test "allows optional is_archived flag", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Archived Project",
        slug: "archived-project",
        is_archived: true,
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :is_archived) == true
    end

    test "defaults is_archived to false" do
      project = %ProjectSchema{}
      assert project.is_archived == false
    end

    test "validates slug uniqueness within workspace", %{user: user, workspace: workspace} do
      # Create first project
      attrs1 = %{
        name: "Project 1",
        slug: "duplicate-slug",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset1 = ProjectSchema.changeset(%ProjectSchema{}, attrs1)
      {:ok, _project1} = Repo.insert(changeset1)

      # Try to create second project with same slug in same workspace
      attrs2 = %{
        name: "Project 2",
        slug: "duplicate-slug",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset2 = ProjectSchema.changeset(%ProjectSchema{}, attrs2)
      assert {:error, changeset} = Repo.insert(changeset2)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "allows same slug in different workspaces", %{user: user} do
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user, %{name: "Workspace 2", slug: "workspace-2"})

      # Create project in workspace1
      attrs1 = %{
        name: "Project 1",
        slug: "same-slug",
        user_id: user.id,
        workspace_id: workspace1.id
      }

      changeset1 = ProjectSchema.changeset(%ProjectSchema{}, attrs1)
      {:ok, _project1} = Repo.insert(changeset1)

      # Create project with same slug in workspace2
      attrs2 = %{
        name: "Project 2",
        slug: "same-slug",
        user_id: user.id,
        workspace_id: workspace2.id
      }

      changeset2 = ProjectSchema.changeset(%ProjectSchema{}, attrs2)
      assert {:ok, _project2} = Repo.insert(changeset2)
    end

    test "validates user_id foreign key", %{workspace: workspace} do
      fake_user_id = Ecto.UUID.generate()

      attrs = %{
        name: "Test Project",
        slug: "test-project",
        user_id: fake_user_id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).user_id
    end

    test "validates workspace_id foreign key", %{user: user} do
      fake_workspace_id = Ecto.UUID.generate()

      attrs = %{
        name: "Test Project",
        slug: "test-project",
        user_id: user.id,
        workspace_id: fake_workspace_id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).workspace_id
    end

    test "casts all fields correctly", %{user: user, workspace: workspace} do
      attrs = %{
        name: "Full Project",
        slug: "full-project",
        description: "Full description",
        color: "#FF5733",
        is_default: true,
        is_archived: true,
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = ProjectSchema.changeset(%ProjectSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Full Project"
      assert Ecto.Changeset.get_change(changeset, :slug) == "full-project"
      assert Ecto.Changeset.get_change(changeset, :description) == "Full description"
      assert Ecto.Changeset.get_change(changeset, :color) == "#FF5733"
      assert Ecto.Changeset.get_change(changeset, :is_default) == true
      assert Ecto.Changeset.get_change(changeset, :is_archived) == true
    end
  end
end
