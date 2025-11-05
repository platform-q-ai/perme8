defmodule Jarga.Projects.Infrastructure.AuthorizationRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Projects.Infrastructure.AuthorizationRepository

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "verify_project_access/3" do
    test "returns {:ok, project} when user owns the project" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:ok, fetched_project} =
               AuthorizationRepository.verify_project_access(user, workspace.id, project.id)

      assert fetched_project.id == project.id
    end

    test "returns {:ok, project} when user is a member of the workspace" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member to workspace
      {:ok, _} = Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :member)

      # Create project by owner
      project = project_fixture(owner, workspace)

      # Member can access project in their workspace
      assert {:ok, fetched_project} =
               AuthorizationRepository.verify_project_access(member, workspace.id, project.id)

      assert fetched_project.id == project.id
    end

    test "returns {:error, :project_not_found} when project doesn't exist" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      fake_project_id = Ecto.UUID.generate()

      assert {:error, :project_not_found} =
               AuthorizationRepository.verify_project_access(user, workspace.id, fake_project_id)
    end

    test "returns {:error, :workspace_not_found} when workspace doesn't exist" do
      user = user_fixture()
      fake_workspace_id = Ecto.UUID.generate()
      fake_project_id = Ecto.UUID.generate()

      assert {:error, :workspace_not_found} =
               AuthorizationRepository.verify_project_access(
                 user,
                 fake_workspace_id,
                 fake_project_id
               )
    end

    test "returns {:error, :unauthorized} when user is not a workspace member" do
      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      assert {:error, :unauthorized} =
               AuthorizationRepository.verify_project_access(non_member, workspace.id, project.id)
    end

    test "returns {:error, :project_not_found} when project belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      assert {:error, :project_not_found} =
               AuthorizationRepository.verify_project_access(user, workspace1.id, project.id)
    end

    test "workspace admins can access all projects in their workspace" do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add admin and member
      {:ok, _} = Jarga.Workspaces.invite_member(owner, workspace.id, admin.email, :admin)
      {:ok, _} = Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :member)

      # Create project by member
      project = project_fixture(member, workspace)

      # Admin can access the project
      assert {:ok, fetched_project} =
               AuthorizationRepository.verify_project_access(admin, workspace.id, project.id)

      assert fetched_project.id == project.id
    end
  end
end
