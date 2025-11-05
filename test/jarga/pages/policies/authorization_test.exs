defmodule Jarga.Pages.Policies.AuthorizationTest do
  use Jarga.DataCase, async: true

  alias Jarga.Pages.Policies.Authorization
  alias Jarga.Pages

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "verify_workspace_access/2" do
    test "returns {:ok, workspace} when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, fetched_workspace} = Authorization.verify_workspace_access(user, workspace.id)
      assert fetched_workspace.id == workspace.id
    end

    test "returns {:error, :workspace_not_found} when workspace doesn't exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :workspace_not_found} = Authorization.verify_workspace_access(user, fake_id)
    end

    test "returns {:error, :unauthorized} when user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      assert {:error, :unauthorized} = Authorization.verify_workspace_access(user2, workspace.id)
    end
  end

  describe "verify_page_access/2" do
    test "returns {:ok, page} when user owns the page" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "My Page"})

      assert {:ok, fetched_page} = Authorization.verify_page_access(user, page.id)
      assert fetched_page.id == page.id
    end

    test "returns {:error, :page_not_found} when page doesn't exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :page_not_found} = Authorization.verify_page_access(user, fake_id)
    end

    test "returns {:error, :unauthorized} when page exists but belongs to another user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, page} = Pages.create_page(user1, workspace.id, %{title: "Private Page"})

      assert {:error, :unauthorized} = Authorization.verify_page_access(user2, page.id)
    end
  end

  describe "verify_project_in_workspace/2" do
    test "returns :ok when project_id is nil" do
      workspace = workspace_fixture(user_fixture())

      assert :ok = Authorization.verify_project_in_workspace(workspace.id, nil)
    end

    test "returns :ok when project belongs to workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert :ok = Authorization.verify_project_in_workspace(workspace.id, project.id)
    end

    test "returns {:error, :invalid_project} when project doesn't exist" do
      workspace = workspace_fixture(user_fixture())
      fake_project_id = Ecto.UUID.generate()

      assert {:error, :invalid_project} =
               Authorization.verify_project_in_workspace(workspace.id, fake_project_id)
    end

    test "returns {:error, :invalid_project} when project belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      assert {:error, :invalid_project} =
               Authorization.verify_project_in_workspace(workspace1.id, project.id)
    end
  end
end
