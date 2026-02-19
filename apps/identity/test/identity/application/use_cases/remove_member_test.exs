defmodule Identity.Application.UseCases.RemoveMemberTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.{InviteMember, RemoveMember}
  alias Identity.Infrastructure.Repositories.MembershipRepository
  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  describe "execute/2 - successful removal" do
    test "removes a member from workspace" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # Add member directly
      _member = add_workspace_member_fixture(workspace.id, member, :admin)

      # Verify member exists
      members = MembershipRepository.list_members(workspace.id)
      assert length(members) == 2

      # Remove member
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:ok, deleted_member} = RemoveMember.execute(params)
      assert deleted_member.user_id == member.id

      # Verify member is removed
      members = MembershipRepository.list_members(workspace.id)
      assert length(members) == 1
      assert hd(members).email == owner.email
    end

    test "removes a pending invitation" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      email = "pending@example.com"

      # Create pending invitation
      {:ok, {:invitation_sent, _}} =
        InviteMember.execute(
          %{inviter: owner, workspace_id: workspace.id, email: email, role: :admin},
          skip_email: true
        )

      # Verify invitation exists
      members = MembershipRepository.list_members(workspace.id)
      assert length(members) == 2

      # Remove invitation
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: email
      }

      assert {:ok, deleted_invitation} = RemoveMember.execute(params)
      assert deleted_invitation.email == email

      # Verify invitation is removed
      members = MembershipRepository.list_members(workspace.id)
      assert length(members) == 1
    end

    test "emits MemberRemoved event when member is removed" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # Add member directly
      _member = add_workspace_member_fixture(workspace.id, member, :admin)

      # Subscribe to the structured event topic
      Phoenix.PubSub.subscribe(Jarga.PubSub, "events:user:#{member.id}")

      # Remove member using default notifier (EmailAndPubSubNotifier)
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:ok, _deleted_member} = RemoveMember.execute(params, [])

      # Verify the structured event was emitted via EventBus
      assert_receive %Identity.Domain.Events.MemberRemoved{
        workspace_id: ws_id,
        target_user_id: target_uid
      }

      assert ws_id == workspace.id
      assert target_uid == member.id
    end

    test "does not broadcast when removing pending invitation" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      email = "pending@example.com"

      # Create pending invitation
      {:ok, {:invitation_sent, _}} =
        InviteMember.execute(
          %{inviter: owner, workspace_id: workspace.id, email: email, role: :admin},
          skip_email: true
        )

      # Subscribe to a hypothetical user topic (no user exists yet)
      Phoenix.PubSub.subscribe(Jarga.PubSub, "user:any")

      # Remove invitation
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: email
      }

      assert {:ok, _deleted_invitation} = RemoveMember.execute(params, [])

      # Verify no broadcast was sent (pending invitations have no user)
      refute_receive {:workspace_removed, _}, 100
    end
  end

  describe "execute/2 - validation errors" do
    test "returns error when trying to remove owner" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: owner.email
      }

      assert {:error, :cannot_remove_owner} = RemoveMember.execute(params, [])
    end

    test "returns error when actor is a member but lacks permission" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()
      guest = user_fixture()

      _member_m = add_workspace_member_fixture(workspace.id, member, :member)
      _guest_m = add_workspace_member_fixture(workspace.id, guest, :guest)

      # Guest cannot remove members
      params = %{
        actor: guest,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:error, :forbidden} = RemoveMember.execute(params)
    end

    test "returns error when actor is a regular member (not admin/owner)" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member1 = user_fixture()
      member2 = user_fixture()

      _m1 = add_workspace_member_fixture(workspace.id, member1, :member)
      _m2 = add_workspace_member_fixture(workspace.id, member2, :member)

      params = %{
        actor: member1,
        workspace_id: workspace.id,
        member_email: member2.email
      }

      assert {:error, :forbidden} = RemoveMember.execute(params)
    end

    test "allows admin to remove member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      admin = user_fixture()
      member = user_fixture()

      _admin_m = add_workspace_member_fixture(workspace.id, admin, :admin)
      _member_m = add_workspace_member_fixture(workspace.id, member, :member)

      params = %{
        actor: admin,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:ok, deleted} = RemoveMember.execute(params)
      assert deleted.user_id == member.id
    end

    test "returns error when actor is not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      member = user_fixture()

      _member = add_workspace_member_fixture(workspace.id, member, :member)

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:error, :unauthorized} = RemoveMember.execute(params, [])
    end

    test "returns error when member not found" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: "nonexistent@example.com"
      }

      assert {:error, :member_not_found} = RemoveMember.execute(params, [])
    end

    test "returns error when workspace not found" do
      owner = user_fixture()
      member = user_fixture()

      params = %{
        actor: owner,
        workspace_id: Ecto.UUID.generate(),
        member_email: member.email
      }

      assert {:error, :workspace_not_found} = RemoveMember.execute(params, [])
    end
  end
end
