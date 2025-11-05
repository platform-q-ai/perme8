defmodule Jarga.WorkspacesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "list_workspaces_for_user/1" do
    test "returns empty list when user has no workspaces" do
      user = user_fixture()
      assert Workspaces.list_workspaces_for_user(user) == []
    end

    test "returns only workspaces where user is a member" do
      user = user_fixture()
      other_user = user_fixture()

      workspace1 = workspace_fixture(user)
      _workspace2 = workspace_fixture(other_user)

      workspaces = Workspaces.list_workspaces_for_user(user)

      assert length(workspaces) == 1
      assert hd(workspaces).id == workspace1.id
    end

    test "returns multiple workspaces for user" do
      user = user_fixture()

      workspace1 = workspace_fixture(user, %{name: "Workspace 1"})
      workspace2 = workspace_fixture(user, %{name: "Workspace 2"})

      workspaces = Workspaces.list_workspaces_for_user(user)

      assert length(workspaces) == 2
      workspace_ids = Enum.map(workspaces, & &1.id)
      assert workspace1.id in workspace_ids
      assert workspace2.id in workspace_ids
    end

    test "does not return archived workspaces" do
      user = user_fixture()

      _active_workspace = workspace_fixture(user, %{name: "Active"})
      _archived_workspace = workspace_fixture(user, %{name: "Archived", is_archived: true})

      workspaces = Workspaces.list_workspaces_for_user(user)

      assert length(workspaces) == 1
      assert hd(workspaces).name == "Active"
    end
  end

  describe "create_workspace/2" do
    test "creates workspace with valid attributes" do
      user = user_fixture()

      attrs = %{
        name: "My Workspace",
        description: "A test workspace",
        color: "#FF5733"
      }

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.name == "My Workspace"
      assert workspace.description == "A test workspace"
      assert workspace.color == "#FF5733"
      assert workspace.is_archived == false
    end

    test "creates workspace with minimal attributes" do
      user = user_fixture()

      attrs = %{name: "Minimal Workspace"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.name == "Minimal Workspace"
      assert workspace.description == nil
      assert workspace.color == nil
    end

    test "creates workspace member with owner role" do
      user = user_fixture()

      attrs = %{name: "My Workspace"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)

      # Verify the user is added as owner
      workspaces = Workspaces.list_workspaces_for_user(user)
      assert length(workspaces) == 1
      assert hd(workspaces).id == workspace.id
    end

    test "returns error for missing name" do
      user = user_fixture()

      attrs = %{description: "No name provided"}

      assert {:error, changeset} = Workspaces.create_workspace(user, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error for empty name" do
      user = user_fixture()

      attrs = %{name: ""}

      assert {:error, changeset} = Workspaces.create_workspace(user, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "get_workspace/2" do
    test "returns workspace when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, fetched} = Workspaces.get_workspace(user, workspace.id)
      assert fetched.id == workspace.id
      assert fetched.name == workspace.name
    end

    test "returns :workspace_not_found when workspace doesn't exist" do
      user = user_fixture()

      assert {:error, :workspace_not_found} = Workspaces.get_workspace(user, Ecto.UUID.generate())
    end

    test "returns :unauthorized when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Workspaces.get_workspace(user, workspace.id)
    end
  end

  describe "get_workspace!/2" do
    test "returns workspace when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert fetched = Workspaces.get_workspace!(user, workspace.id)
      assert fetched.id == workspace.id
      assert fetched.name == workspace.name
    end

    test "raises when workspace doesn't exist" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, Ecto.UUID.generate())
      end
    end

    test "raises when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, workspace.id)
      end
    end
  end

  describe "update_workspace/3" do
    test "updates workspace with valid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Original Name"})

      attrs = %{name: "Updated Name", description: "Updated description"}

      assert {:ok, updated_workspace} = Workspaces.update_workspace(user, workspace.id, attrs)
      assert updated_workspace.name == "Updated Name"
      assert updated_workspace.description == "Updated description"
      assert updated_workspace.id == workspace.id
    end

    test "updates workspace with partial attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Original", description: "Original desc"})

      attrs = %{name: "New Name"}

      assert {:ok, updated_workspace} = Workspaces.update_workspace(user, workspace.id, attrs)
      assert updated_workspace.name == "New Name"
      assert updated_workspace.description == "Original desc"
    end

    test "returns error for invalid attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{name: ""}

      assert {:error, changeset} = Workspaces.update_workspace(user, workspace.id, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      attrs = %{name: "Updated Name"}

      assert {:error, :unauthorized} = Workspaces.update_workspace(user, workspace.id, attrs)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      attrs = %{name: "Updated Name"}

      assert {:error, :workspace_not_found} =
               Workspaces.update_workspace(user, Ecto.UUID.generate(), attrs)
    end
  end

  describe "delete_workspace/2" do
    test "deletes workspace when user is owner" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, deleted_workspace} = Workspaces.delete_workspace(user, workspace.id)
      assert deleted_workspace.id == workspace.id

      # Verify workspace is deleted
      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(user, workspace.id)
      end
    end

    test "deletes workspace and cascades to projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:ok, _deleted_workspace} = Workspaces.delete_workspace(user, workspace.id)

      # Verify project is also deleted
      assert Repo.get(Jarga.Projects.Project, project.id) == nil
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Workspaces.delete_workspace(user, workspace.id)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      assert {:error, :workspace_not_found} =
               Workspaces.delete_workspace(user, Ecto.UUID.generate())
    end
  end

  describe "invite_member/4 - existing user" do
    test "successfully invites an existing user as admin" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      assert {:ok, {:member_added, member}} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :admin)

      assert member.workspace_id == workspace.id
      assert member.user_id == invitee.id
      assert member.email == invitee.email
      assert member.role == :admin
      assert member.invited_by == owner.id
      assert member.invited_at != nil
      assert member.joined_at != nil
    end

    test "successfully invites an existing user as member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      assert {:ok, {:member_added, member}} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :member)

      assert member.role == :member
    end

    test "successfully invites an existing user as guest" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      assert {:ok, {:member_added, member}} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :guest)

      assert member.role == :guest
    end

    test "returns error when inviting with owner role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      assert {:error, :invalid_role} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :owner)
    end

    test "returns error when user is already a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      # First invitation succeeds
      assert {:ok, {:member_added, _member}} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :admin)

      # Second invitation fails
      assert {:error, :already_member} =
               Workspaces.invite_member(owner, workspace.id, invitee.email, :admin)
    end

    test "returns error when inviter is not a member of workspace" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      invitee = user_fixture()

      assert {:error, :unauthorized} =
               Workspaces.invite_member(non_member, workspace.id, invitee.email, :admin)
    end

    test "returns error when workspace does not exist" do
      owner = user_fixture()
      invitee = user_fixture()

      assert {:error, :workspace_not_found} =
               Workspaces.invite_member(owner, Ecto.UUID.generate(), invitee.email, :admin)
    end
  end

  describe "invite_member/4 - non-existing user" do
    test "creates pending invitation for non-existing user" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      email = "newuser@example.com"

      assert {:ok, {:invitation_sent, invitation}} =
               Workspaces.invite_member(owner, workspace.id, email, :admin)

      assert invitation.workspace_id == workspace.id
      assert invitation.user_id == nil
      assert invitation.email == email
      assert invitation.role == :admin
      assert invitation.invited_by == owner.id
      assert invitation.invited_at != nil
      assert invitation.joined_at == nil
    end

    test "email is case-insensitive when checking for existing users" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture(%{email: "User@Example.Com"})

      # Should find existing user despite case difference
      assert {:ok, {:member_added, member}} =
               Workspaces.invite_member(owner, workspace.id, "user@example.com", :admin)

      assert member.user_id == invitee.id
    end
  end

  describe "list_members/1" do
    test "returns all members of a workspace" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member1 = user_fixture()
      member2 = user_fixture()

      {:ok, {:member_added, _}} =
        Workspaces.invite_member(owner, workspace.id, member1.email, :admin)

      {:ok, {:member_added, _}} =
        Workspaces.invite_member(owner, workspace.id, member2.email, :member)

      members = Workspaces.list_members(workspace.id)

      assert length(members) == 3
      member_emails = Enum.map(members, & &1.email)
      assert owner.email in member_emails
      assert member1.email in member_emails
      assert member2.email in member_emails
    end

    test "returns empty list when workspace has no members" do
      # This shouldn't happen in practice, but test the query
      assert Workspaces.list_members(Ecto.UUID.generate()) == []
    end

    test "includes pending invitations" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      {:ok, {:invitation_sent, _}} =
        Workspaces.invite_member(owner, workspace.id, "pending@example.com", :admin)

      members = Workspaces.list_members(workspace.id)

      assert length(members) == 2
      pending = Enum.find(members, &(&1.email == "pending@example.com"))
      assert pending.user_id == nil
      assert pending.joined_at == nil
    end
  end

  describe "change_member_role/4" do
    test "successfully changes member role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      {:ok, {:member_added, _}} =
        Workspaces.invite_member(owner, workspace.id, member.email, :admin)

      assert {:ok, updated_member} =
               Workspaces.change_member_role(owner, workspace.id, member.email, :member)

      assert updated_member.role == :member
    end

    test "returns error when trying to change owner role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      assert {:error, :cannot_change_owner_role} =
               Workspaces.change_member_role(owner, workspace.id, owner.email, :admin)
    end

    test "returns error when actor not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      member = user_fixture()

      {:ok, {:member_added, _}} =
        Workspaces.invite_member(owner, workspace.id, member.email, :admin)

      assert {:error, :unauthorized} =
               Workspaces.change_member_role(non_member, workspace.id, member.email, :member)
    end

    test "returns error when member not found" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      assert {:error, :member_not_found} =
               Workspaces.change_member_role(
                 owner,
                 workspace.id,
                 "nonexistent@example.com",
                 :admin
               )
    end
  end

  describe "remove_member/3" do
    test "successfully removes a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      {:ok, {:member_added, _}} =
        Workspaces.invite_member(owner, workspace.id, member.email, :admin)

      # Verify member exists
      members_before = Workspaces.list_members(workspace.id)
      assert length(members_before) == 2

      assert {:ok, deleted_member} = Workspaces.remove_member(owner, workspace.id, member.email)
      assert deleted_member.user_id == member.id

      # Verify member removed
      members_after = Workspaces.list_members(workspace.id)
      assert length(members_after) == 1
    end

    test "successfully removes a pending invitation" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      email = "pending@example.com"

      {:ok, {:invitation_sent, _}} = Workspaces.invite_member(owner, workspace.id, email, :admin)

      assert {:ok, deleted_invitation} = Workspaces.remove_member(owner, workspace.id, email)
      assert deleted_invitation.email == email
    end

    test "returns error when trying to remove owner" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      assert {:error, :cannot_remove_owner} =
               Workspaces.remove_member(owner, workspace.id, owner.email)
    end

    test "returns error when actor not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      member = user_fixture()

      {:ok, {:member_added, _}} =
        Workspaces.invite_member(owner, workspace.id, member.email, :admin)

      assert {:error, :unauthorized} =
               Workspaces.remove_member(non_member, workspace.id, member.email)
    end

    test "returns error when member not found" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      assert {:error, :member_not_found} =
               Workspaces.remove_member(owner, workspace.id, "nonexistent@example.com")
    end
  end

  describe "workspace slugs" do
    test "generates slug from name on create" do
      user = user_fixture()
      attrs = %{name: "My Awesome Workspace"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.slug == "my-awesome-workspace"
    end

    test "generates slug with special characters removed" do
      user = user_fixture()
      attrs = %{name: "My Workspace! @#$%"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.slug == "my-workspace"
    end

    test "generates slug with consecutive spaces normalized" do
      user = user_fixture()
      attrs = %{name: "My    Multiple   Spaces"}

      assert {:ok, workspace} = Workspaces.create_workspace(user, attrs)
      assert workspace.slug == "my-multiple-spaces"
    end

    test "handles slug collisions by appending random suffix" do
      user = user_fixture()
      attrs = %{name: "Duplicate Name"}

      assert {:ok, workspace1} = Workspaces.create_workspace(user, attrs)
      assert workspace1.slug == "duplicate-name"

      assert {:ok, workspace2} = Workspaces.create_workspace(user, attrs)
      # Should have random suffix appended
      assert workspace2.slug =~ ~r/^duplicate-name-[a-z0-9]+$/
      assert workspace2.slug != workspace1.slug
    end

    test "keeps slug stable when name changes" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Original Name"})

      assert workspace.slug == "original-name"

      assert {:ok, updated_workspace} =
               Workspaces.update_workspace(user, workspace.id, %{name: "New Name"})

      assert updated_workspace.slug == "original-name"
      assert updated_workspace.name == "New Name"
    end

    test "keeps original slug when updating name to existing name" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "First Workspace"})
      workspace2 = workspace_fixture(user, %{name: "Second Workspace"})

      assert workspace1.slug == "first-workspace"
      assert workspace2.slug == "second-workspace"

      # Update workspace2 to have same name as workspace1
      assert {:ok, updated} =
               Workspaces.update_workspace(user, workspace2.id, %{name: "First Workspace"})

      # Slug should remain unchanged
      assert updated.slug == "second-workspace"
      assert updated.name == "First Workspace"
    end
  end

  describe "get_workspace_by_slug/2" do
    test "returns workspace when user is a member and slug matches" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "My Workspace"})

      assert {:ok, fetched} = Workspaces.get_workspace_by_slug(user, "my-workspace")
      assert fetched.id == workspace.id
      assert fetched.name == workspace.name
    end

    test "returns :workspace_not_found when workspace doesn't exist" do
      user = user_fixture()

      assert {:error, :workspace_not_found} =
               Workspaces.get_workspace_by_slug(user, "nonexistent")
    end

    test "returns :workspace_not_found when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      _workspace = workspace_fixture(other_user, %{name: "Other Workspace"})

      assert {:error, :workspace_not_found} =
               Workspaces.get_workspace_by_slug(user, "other-workspace")
    end
  end
end
