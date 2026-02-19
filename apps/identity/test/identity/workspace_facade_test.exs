defmodule Identity.WorkspaceFacadeTest do
  use Identity.DataCase, async: true

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  describe "list_workspaces_for_user/1" do
    test "returns workspace list for a user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      workspaces = Identity.list_workspaces_for_user(user)
      assert length(workspaces) == 1
      assert hd(workspaces).id == workspace.id
    end

    test "returns empty list for user with no workspaces" do
      user = user_fixture()

      assert Identity.list_workspaces_for_user(user) == []
    end
  end

  describe "create_workspace/2" do
    test "creates workspace with owner member" do
      user = user_fixture()

      assert {:ok, workspace} =
               Identity.create_workspace(user, %{name: "Test Workspace"})

      assert workspace.name == "Test Workspace"
      assert workspace.slug != nil
    end

    test "returns error for invalid attrs" do
      user = user_fixture()

      assert {:error, changeset} = Identity.create_workspace(user, %{name: ""})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "get_workspace/2" do
    test "returns workspace when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, returned} = Identity.get_workspace(user, workspace.id)
      assert returned.id == workspace.id
    end

    test "returns error when user is not member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Identity.get_workspace(user, workspace.id)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      assert {:error, :workspace_not_found} =
               Identity.get_workspace(user, Ecto.UUID.generate())
    end
  end

  describe "get_workspace!/2" do
    test "returns workspace when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      returned = Identity.get_workspace!(user, workspace.id)
      assert returned.id == workspace.id
    end

    test "raises when not found" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Identity.get_workspace!(user, Ecto.UUID.generate())
      end
    end
  end

  describe "get_workspace_by_slug/2" do
    test "returns workspace when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, returned} = Identity.get_workspace_by_slug(user, workspace.slug)
      assert returned.id == workspace.id
    end

    test "returns error when not found" do
      user = user_fixture()

      assert {:error, :workspace_not_found} =
               Identity.get_workspace_by_slug(user, "nonexistent-slug")
    end
  end

  describe "get_workspace_by_slug!/2" do
    test "returns workspace when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      returned = Identity.get_workspace_by_slug!(user, workspace.slug)
      assert returned.id == workspace.id
    end

    test "raises when not found" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Identity.get_workspace_by_slug!(user, "nonexistent-slug")
      end
    end
  end

  describe "get_workspace_and_member_by_slug/2" do
    test "returns {:ok, workspace, member}" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, returned_workspace, member} =
               Identity.get_workspace_and_member_by_slug(user, workspace.slug)

      assert returned_workspace.id == workspace.id
      assert member.user_id == user.id
      assert member.role == :owner
    end

    test "returns error when not found" do
      user = user_fixture()

      assert {:error, :workspace_not_found} =
               Identity.get_workspace_and_member_by_slug(user, "nonexistent")
    end
  end

  describe "update_workspace/3" do
    test "updates workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, updated} =
               Identity.update_workspace(user, workspace.id, %{"name" => "Updated"})

      assert updated.name == "Updated"
    end

    test "returns error for non-member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()

      assert {:error, :unauthorized} =
               Identity.update_workspace(non_member, workspace.id, %{"name" => "Updated"})
    end

    test "returns error when guest tries to edit" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      guest = user_fixture()
      _member = add_workspace_member_fixture(workspace.id, guest, :guest)

      assert {:error, :forbidden} =
               Identity.update_workspace(guest, workspace.id, %{"name" => "Updated"})
    end
  end

  describe "delete_workspace/2" do
    test "deletes workspace when owner" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, deleted} = Identity.delete_workspace(user, workspace.id)
      assert deleted.id == workspace.id
    end

    test "returns error when not owner" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      admin = user_fixture()
      _member = add_workspace_member_fixture(workspace.id, admin, :admin)

      assert {:error, :forbidden} = Identity.delete_workspace(admin, workspace.id)
    end
  end

  describe "verify_membership/2" do
    test "verifies user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, _workspace} = Identity.verify_membership(user, workspace.id)
    end

    test "returns error when not member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Identity.verify_membership(user, workspace.id)
    end
  end

  describe "member?/2" do
    test "returns true when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert Identity.member?(user.id, workspace.id)
    end

    test "returns false when not member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      refute Identity.member?(user.id, workspace.id)
    end
  end

  describe "member_by_slug?/2" do
    test "returns true when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert Identity.member_by_slug?(user.id, workspace.slug)
    end

    test "returns false when not member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      refute Identity.member_by_slug?(user.id, workspace.slug)
    end
  end

  describe "get_member/2" do
    test "gets member record" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, member} = Identity.get_member(user, workspace.id)
      assert member.role == :owner
    end

    test "returns error when not member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert {:error, :unauthorized} = Identity.get_member(user, workspace.id)
    end
  end

  describe "invite_member/4" do
    test "invites user to workspace" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      assert {:ok, {:invitation_sent, invitation}} =
               Identity.invite_member(owner, workspace.id, "new@example.com", :member,
                 skip_email: true
               )

      assert invitation.email == "new@example.com"
      assert invitation.role == :member
    end
  end

  describe "list_members/1" do
    test "lists workspace members" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      members = Identity.list_members(workspace.id)
      assert length(members) == 1
      assert hd(members).email == user.email
    end
  end

  describe "accept_pending_invitations/1" do
    test "accepts all pending invitations" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      # Create pending invitation directly
      _invitation =
        pending_invitation_fixture(workspace.id, invitee.email, :member, invited_by: owner.id)

      assert {:ok, accepted} = Identity.accept_pending_invitations(invitee)
      assert length(accepted) == 1
      assert hd(accepted).user_id == invitee.id
    end

    test "returns empty list when no pending invitations" do
      user = user_fixture()

      assert {:ok, []} = Identity.accept_pending_invitations(user)
    end
  end

  describe "accept_invitation_by_workspace/2" do
    test "accepts specific invitation" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      # Create pending invitation directly
      _invitation =
        pending_invitation_fixture(workspace.id, invitee.email, :member, invited_by: owner.id)

      assert {:ok, member} =
               Identity.accept_invitation_by_workspace(workspace.id, invitee.id)

      assert member.user_id == invitee.id
      assert member.joined_at != nil
    end

    test "returns error when invitation not found" do
      user = user_fixture()

      assert {:error, :invitation_not_found} =
               Identity.accept_invitation_by_workspace(Ecto.UUID.generate(), user.id)
    end
  end

  describe "decline_invitation_by_workspace/2" do
    test "declines invitation" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      _invitation =
        pending_invitation_fixture(workspace.id, invitee.email, :member, invited_by: owner.id)

      assert :ok = Identity.decline_invitation_by_workspace(workspace.id, invitee.id)
    end

    test "returns ok when invitation not found" do
      user = user_fixture()

      assert :ok = Identity.decline_invitation_by_workspace(Ecto.UUID.generate(), user.id)
    end
  end

  describe "list_pending_invitations_with_details/1" do
    test "lists pending invitations with preloads" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      _invitation =
        pending_invitation_fixture(workspace.id, "invited@example.com", :member,
          invited_by: owner.id
        )

      invitations = Identity.list_pending_invitations_with_details("invited@example.com")
      assert length(invitations) == 1
    end
  end

  describe "create_notifications_for_pending_invitations/1" do
    test "creates notifications" do
      user = user_fixture()

      assert {:ok, []} = Identity.create_notifications_for_pending_invitations(user)
    end
  end

  describe "change_member_role/4" do
    test "changes role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()
      _member = add_workspace_member_fixture(workspace.id, member, :member)

      assert {:ok, updated} =
               Identity.change_member_role(owner, workspace.id, member.email, :admin)

      assert updated.role == :admin
    end
  end

  describe "remove_member/3" do
    test "removes member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()
      _member = add_workspace_member_fixture(workspace.id, member, :member)

      assert {:ok, deleted} =
               Identity.remove_member(owner, workspace.id, member.email)

      assert deleted.user_id == member.id
    end
  end

  describe "change_workspace/0 and change_workspace/2" do
    test "returns changeset for new workspace" do
      changeset = Identity.change_workspace()
      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset for editing workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      changeset = Identity.change_workspace(workspace)
      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset with attrs" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      changeset = Identity.change_workspace(workspace, %{name: "Updated"})
      assert %Ecto.Changeset{} = changeset
    end
  end
end
