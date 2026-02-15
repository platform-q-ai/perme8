defmodule Jarga.WorkspacesTest do
  @moduledoc """
  Tests that Jarga.Workspaces facade correctly delegates to Identity.

  The comprehensive workspace logic tests live in the Identity app.
  These tests verify the delegation layer preserves the expected API.
  """
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "list_workspaces_for_user/1" do
    test "delegates to Identity and returns workspaces" do
      user = user_fixture()
      assert Workspaces.list_workspaces_for_user(user) == []

      workspace = workspace_fixture(user)
      workspaces = Workspaces.list_workspaces_for_user(user)
      assert length(workspaces) == 1
      assert hd(workspaces).id == workspace.id
    end

    test "does not return archived workspaces" do
      user = user_fixture()
      _active = workspace_fixture(user, %{name: "Active"})
      _archived = workspace_fixture(user, %{name: "Archived", is_archived: true})

      workspaces = Workspaces.list_workspaces_for_user(user)
      assert length(workspaces) == 1
      assert hd(workspaces).name == "Active"
    end
  end

  describe "create_workspace/2" do
    test "delegates to Identity and creates workspace" do
      user = user_fixture()
      attrs = %{name: "My Workspace", description: "A test workspace", color: "#FF5733"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.name == "My Workspace"
      assert workspace.description == "A test workspace"
      assert workspace.color == "#FF5733"
      assert workspace.is_archived == false
    end

    test "returns error for invalid attributes" do
      user = user_fixture()
      assert {:error, changeset} = Workspaces.create_workspace(user, %{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "get_workspace/2" do
    test "returns workspace for member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, fetched} = Workspaces.get_workspace(user, workspace.id)
      assert fetched.id == workspace.id
    end

    test "returns error for non-member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Workspaces.get_workspace(user, workspace.id)
    end

    test "returns error for nonexistent workspace" do
      user = user_fixture()
      assert {:error, :workspace_not_found} = Workspaces.get_workspace(user, Ecto.UUID.generate())
    end
  end

  describe "get_workspace!/2" do
    test "returns workspace for member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert fetched = Workspaces.get_workspace!(user, workspace.id)
      assert fetched.id == workspace.id
    end

    test "raises for nonexistent workspace" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, Ecto.UUID.generate())
      end
    end
  end

  describe "update_workspace/3" do
    test "delegates to Identity and updates workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Original Name"})

      assert {:ok, updated} =
               Workspaces.update_workspace(user, workspace.id, %{name: "Updated Name"})

      assert updated.name == "Updated Name"
    end

    test "returns error for non-member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} =
               Workspaces.update_workspace(user, workspace.id, %{name: "Updated"})
    end
  end

  describe "delete_workspace/2" do
    test "delegates to Identity and deletes workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, deleted} = Workspaces.delete_workspace(user, workspace.id)
      assert deleted.id == workspace.id
    end

    test "cascades to projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:ok, _} = Workspaces.delete_workspace(user, workspace.id)
      assert Repo.get(Jarga.Projects.Infrastructure.Schemas.ProjectSchema, project.id) == nil
    end
  end

  describe "invite_member/4" do
    test "delegates to Identity" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      assert {:ok, {:invitation_sent, invitation}} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :admin)

      assert invitation.workspace_id == workspace.id
      assert invitation.email == invitee.email
      assert invitation.role == :admin
    end

    test "returns error for invalid role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      assert {:error, :invalid_role} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :owner)
    end
  end

  describe "list_members/1" do
    test "delegates to Identity" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      members = Workspaces.list_members(workspace.id)
      assert length(members) == 1
      assert hd(members).email == owner.email
    end
  end

  describe "change_member_role/4" do
    test "delegates to Identity" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :admin)

      assert {:ok, updated} =
               Workspaces.change_member_role(owner, workspace.id, member.email, :member)

      assert updated.role == :member
    end
  end

  describe "remove_member/3" do
    test "delegates to Identity" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :admin)
      assert {:ok, deleted} = Workspaces.remove_member(owner, workspace.id, member.email)
      assert deleted.user_id == member.id
    end
  end

  describe "workspace slugs" do
    test "generates slug from name" do
      user = user_fixture()
      assert {:ok, workspace} = Workspaces.create_workspace(user, %{name: "My Awesome Workspace"})
      assert workspace.slug == "my-awesome-workspace"
    end
  end

  describe "get_workspace_by_slug/2" do
    test "delegates to Identity" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "My Workspace"})

      assert {:ok, fetched} = Workspaces.get_workspace_by_slug(user, "my-workspace")
      assert fetched.id == workspace.id
    end
  end

  describe "accept_pending_invitations/1" do
    test "delegates to Identity" do
      owner = user_fixture()
      workspace = workspace_fixture(owner, %{name: "Workspace 1"})
      email = "newuser@example.com"

      {:ok, {:invitation_sent, _}} =
        Workspaces.invite_member(owner, workspace.id, email, :admin)

      new_user = user_fixture(%{email: email})

      assert {:ok, accepted} = Workspaces.accept_pending_invitations(new_user)
      assert length(accepted) == 1
    end
  end

  describe "verify_membership/2" do
    test "delegates to Identity" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, _workspace} = Workspaces.verify_membership(user, workspace.id)
    end
  end

  describe "member?/2" do
    test "delegates to Identity" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert Workspaces.member?(user.id, workspace.id)
      refute Workspaces.member?(user.id, Ecto.UUID.generate())
    end
  end

  describe "change_workspace/0 and change_workspace/2" do
    test "returns changeset for new workspace" do
      changeset = Workspaces.change_workspace()
      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset for existing workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      changeset = Workspaces.change_workspace(workspace)
      assert %Ecto.Changeset{} = changeset
    end
  end
end
