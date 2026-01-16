defmodule Jarga.Documents.Infrastructure.Schemas.DocumentSchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

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
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert changeset.valid?
    end

    test "requires title", %{user: user, workspace: workspace} do
      attrs = %{
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).title
    end

    test "requires slug", %{user: user, workspace: workspace} do
      attrs = %{
        title: "Test Document",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).slug
    end

    test "requires user_id", %{workspace: workspace, user: creator} do
      attrs = %{
        title: "Test Document",
        slug: "test-document",
        workspace_id: workspace.id,
        created_by: creator.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires workspace_id", %{user: user} do
      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "requires created_by", %{user: user, workspace: workspace} do
      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).created_by
    end

    test "validates title minimum length", %{user: user, workspace: workspace} do
      attrs = %{
        title: "",
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).title
    end

    test "allows optional project_id", %{user: user, workspace: workspace} do
      project = project_fixture(user, workspace)

      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id,
        project_id: project.id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :project_id) == project.id
    end

    test "allows optional is_public flag", %{user: user, workspace: workspace} do
      attrs = %{
        title: "Public Document",
        slug: "public-page",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id,
        is_public: true
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :is_public) == true
    end

    test "defaults is_public to false" do
      document = %DocumentSchema{}
      assert document.is_public == false
    end

    test "allows optional is_pinned flag", %{user: user, workspace: workspace} do
      attrs = %{
        title: "Pinned Document",
        slug: "pinned-page",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id,
        is_pinned: true
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :is_pinned) == true
    end

    test "defaults is_pinned to false" do
      document = %DocumentSchema{}
      assert document.is_pinned == false
    end

    test "validates slug uniqueness within workspace", %{user: user, workspace: workspace} do
      # Create first document
      attrs1 = %{
        title: "Document 1",
        slug: "duplicate-slug",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id
      }

      changeset1 = DocumentSchema.changeset(%DocumentSchema{}, attrs1)
      {:ok, _document1} = Repo.insert(changeset1)

      # Try to create second document with same slug in same workspace
      attrs2 = %{
        title: "Document 2",
        slug: "duplicate-slug",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: user.id
      }

      changeset2 = DocumentSchema.changeset(%DocumentSchema{}, attrs2)
      assert {:error, changeset} = Repo.insert(changeset2)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "allows same slug in different workspaces", %{user: user} do
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user, %{name: "Workspace 2", slug: "workspace-2"})

      # Create document in workspace1
      attrs1 = %{
        title: "Document 1",
        slug: "same-slug",
        user_id: user.id,
        workspace_id: workspace1.id,
        created_by: user.id
      }

      changeset1 = DocumentSchema.changeset(%DocumentSchema{}, attrs1)
      {:ok, _document1} = Repo.insert(changeset1)

      # Create document with same slug in workspace2
      attrs2 = %{
        title: "Document 2",
        slug: "same-slug",
        user_id: user.id,
        workspace_id: workspace2.id,
        created_by: user.id
      }

      changeset2 = DocumentSchema.changeset(%DocumentSchema{}, attrs2)
      assert {:ok, _document2} = Repo.insert(changeset2)
    end

    test "validates user_id foreign key", %{workspace: workspace} do
      fake_user_id = Ecto.UUID.generate()

      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: fake_user_id,
        workspace_id: workspace.id,
        created_by: fake_user_id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).user_id
    end

    test "validates workspace_id foreign key", %{user: user} do
      fake_workspace_id = Ecto.UUID.generate()

      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        workspace_id: fake_workspace_id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).workspace_id
    end

    test "validates project_id foreign key when provided", %{user: user, workspace: workspace} do
      fake_project_id = Ecto.UUID.generate()

      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id,
        project_id: fake_project_id,
        created_by: user.id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).project_id
    end

    test "validates created_by foreign key", %{user: user, workspace: workspace} do
      fake_creator_id = Ecto.UUID.generate()

      attrs = %{
        title: "Test Document",
        slug: "test-document",
        user_id: user.id,
        workspace_id: workspace.id,
        created_by: fake_creator_id
      }

      changeset = DocumentSchema.changeset(%DocumentSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).created_by
    end
  end
end
