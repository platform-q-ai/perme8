defmodule Jarga.Workspaces.Infrastructure.MembershipRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Infrastructure.MembershipRepository
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "get_workspace_for_user/2" do
    test "returns workspace when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert fetched_workspace = MembershipRepository.get_workspace_for_user(user, workspace.id)
      assert fetched_workspace.id == workspace.id
    end

    test "returns nil when user is not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()

      assert MembershipRepository.get_workspace_for_user(non_member, workspace.id) == nil
    end

    test "returns nil when workspace doesn't exist" do
      user = user_fixture()
      non_existent_id = Ecto.UUID.generate()

      assert MembershipRepository.get_workspace_for_user(user, non_existent_id) == nil
    end
  end

  describe "workspace_exists?/1" do
    test "returns true when workspace exists" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.workspace_exists?(workspace.id) == true
    end

    test "returns false when workspace doesn't exist" do
      non_existent_id = Ecto.UUID.generate()

      assert MembershipRepository.workspace_exists?(non_existent_id) == false
    end
  end

  describe "find_member_by_email/2" do
    test "returns member when email matches" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # Add member to workspace
      Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :admin)

      assert found_member = MembershipRepository.find_member_by_email(workspace.id, member.email)
      assert found_member.email == member.email
    end

    test "returns nil when email doesn't match any member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.find_member_by_email(workspace.id, "nonexistent@example.com") ==
               nil
    end

    test "is case-insensitive" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture(%{email: "User@Example.Com"})

      # Add member to workspace
      Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :admin)

      # Search with different case
      assert found_member =
               MembershipRepository.find_member_by_email(workspace.id, "user@example.com")

      assert found_member.email == member.email
    end
  end

  describe "email_is_member?/2" do
    test "returns true when email is a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      assert MembershipRepository.email_is_member?(workspace.id, owner.email) == true
    end

    test "returns false when email is not a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.email_is_member?(workspace.id, "nonmember@example.com") ==
               false
    end
  end

  describe "list_members/1" do
    test "returns all members of a workspace" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member1 = user_fixture()
      member2 = user_fixture()

      # Add members
      Jarga.Workspaces.invite_member(owner, workspace.id, member1.email, :admin)
      Jarga.Workspaces.invite_member(owner, workspace.id, member2.email, :member)

      members = MembershipRepository.list_members(workspace.id)

      assert length(members) == 3
      assert Enum.any?(members, &(&1.email == owner.email))
      assert Enum.any?(members, &(&1.email == member1.email))
      assert Enum.any?(members, &(&1.email == member2.email))
    end

    test "returns empty list when workspace has no members" do
      # Create a workspace directly without members (not normal, but tests repository)
      workspace_id = Ecto.UUID.generate()

      assert MembershipRepository.list_members(workspace_id) == []
    end

    test "includes pending invitations" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Add pending invitation
      Jarga.Workspaces.invite_member(owner, workspace.id, "pending@example.com", :admin)

      members = MembershipRepository.list_members(workspace.id)

      assert length(members) == 2
      assert Enum.any?(members, &(&1.email == "pending@example.com" and is_nil(&1.user_id)))
    end
  end
end
