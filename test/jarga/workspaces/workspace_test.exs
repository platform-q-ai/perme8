defmodule Jarga.Workspaces.WorkspaceTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Workspace

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        name: "Test Workspace",
        slug: "test-workspace"
      }

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert changeset.valid?
    end

    test "requires name" do
      attrs = %{slug: "test-workspace"}

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires slug" do
      attrs = %{name: "Test Workspace"}

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert "can't be blank" in errors_on(changeset).slug
    end

    test "validates name minimum length" do
      attrs = %{
        name: "",
        slug: "test-workspace"
      }

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "allows optional description" do
      attrs = %{
        name: "Test Workspace",
        slug: "test-workspace",
        description: "A test workspace description"
      }

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :description) == "A test workspace description"
    end

    test "allows optional color" do
      attrs = %{
        name: "Test Workspace",
        slug: "test-workspace",
        color: "#3B82F6"
      }

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :color) == "#3B82F6"
    end

    test "allows optional is_archived flag" do
      attrs = %{
        name: "Archived Workspace",
        slug: "archived-workspace",
        is_archived: true
      }

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :is_archived) == true
    end

    test "defaults is_archived to false" do
      workspace = %Workspace{}
      assert workspace.is_archived == false
    end

    test "validates slug uniqueness" do
      # Create first workspace
      attrs1 = %{
        name: "Workspace 1",
        slug: "duplicate-slug"
      }

      changeset1 = Workspace.changeset(%Workspace{}, attrs1)
      {:ok, _workspace1} = Repo.insert(changeset1)

      # Try to create second workspace with same slug
      attrs2 = %{
        name: "Workspace 2",
        slug: "duplicate-slug"
      }

      changeset2 = Workspace.changeset(%Workspace{}, attrs2)
      assert {:error, changeset} = Repo.insert(changeset2)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "casts all fields correctly" do
      attrs = %{
        name: "Full Workspace",
        slug: "full-workspace",
        description: "Full description",
        color: "#EF4444",
        is_archived: true
      }

      changeset = Workspace.changeset(%Workspace{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Full Workspace"
      assert Ecto.Changeset.get_change(changeset, :slug) == "full-workspace"
      assert Ecto.Changeset.get_change(changeset, :description) == "Full description"
      assert Ecto.Changeset.get_change(changeset, :color) == "#EF4444"
      assert Ecto.Changeset.get_change(changeset, :is_archived) == true
    end
  end
end
