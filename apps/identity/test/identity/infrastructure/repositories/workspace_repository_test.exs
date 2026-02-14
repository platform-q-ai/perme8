defmodule Identity.Infrastructure.Repositories.WorkspaceRepositoryTest do
  use Identity.DataCase, async: true

  alias Identity.Infrastructure.Repositories.WorkspaceRepository
  alias Identity.Infrastructure.Schemas.WorkspaceSchema
  alias Identity.Domain.Entities.Workspace

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  describe "get_by_id/1" do
    test "returns workspace entity when found" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = WorkspaceRepository.get_by_id(workspace.id)
      assert %Workspace{} = result
      assert result.id == workspace.id
      assert result.name == workspace.name
    end

    test "returns nil when not found" do
      assert WorkspaceRepository.get_by_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "insert/1" do
    test "creates workspace from attrs" do
      {:ok, workspace} =
        WorkspaceRepository.insert(%{
          name: "New Workspace",
          slug: "new-workspace"
        })

      assert %Workspace{} = workspace
      assert workspace.name == "New Workspace"
      assert workspace.slug == "new-workspace"
      assert workspace.id != nil
    end

    test "returns error for invalid attrs" do
      {:error, %Ecto.Changeset{}} = WorkspaceRepository.insert(%{})
    end
  end

  describe "update/2" do
    test "updates workspace fields with domain entity" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, updated} = WorkspaceRepository.update(workspace, %{name: "Updated Name"})
      assert %Workspace{} = updated
      assert updated.name == "Updated Name"
    end

    test "updates workspace fields with schema struct" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      schema = WorkspaceSchema.to_schema(workspace)

      {:ok, updated} = WorkspaceRepository.update(schema, %{name: "Updated Via Schema"})
      assert %Workspace{} = updated
      assert updated.name == "Updated Via Schema"
    end

    test "returns error for invalid update" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:error, %Ecto.Changeset{}} = WorkspaceRepository.update(workspace, %{name: ""})
    end
  end

  describe "insert_changeset/1" do
    test "inserts from changeset" do
      changeset =
        WorkspaceSchema.changeset(%WorkspaceSchema{}, %{
          name: "From Changeset",
          slug: "from-changeset"
        })

      {:ok, workspace} = WorkspaceRepository.insert_changeset(changeset)
      assert %Workspace{} = workspace
      assert workspace.name == "From Changeset"
    end

    test "returns error for invalid changeset" do
      changeset = WorkspaceSchema.changeset(%WorkspaceSchema{}, %{})
      {:error, %Ecto.Changeset{}} = WorkspaceRepository.insert_changeset(changeset)
    end
  end
end
