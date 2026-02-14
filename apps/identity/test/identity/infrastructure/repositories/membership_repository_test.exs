defmodule Identity.Infrastructure.Repositories.MembershipRepositoryTest do
  use Identity.DataCase, async: true

  alias Identity.Infrastructure.Repositories.MembershipRepository
  alias Identity.Domain.Entities.{Workspace, WorkspaceMember}

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  describe "get_workspace_for_user/2" do
    test "returns workspace when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = MembershipRepository.get_workspace_for_user(user, workspace.id)
      assert %Workspace{} = result
      assert result.id == workspace.id
    end

    test "returns nil when user is not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()

      assert MembershipRepository.get_workspace_for_user(non_member, workspace.id) == nil
    end

    test "returns nil when workspace doesn't exist" do
      user = user_fixture()
      assert MembershipRepository.get_workspace_for_user(user, Ecto.UUID.generate()) == nil
    end
  end

  describe "get_workspace_for_user_by_slug/2" do
    test "returns workspace by slug when user is member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = MembershipRepository.get_workspace_for_user_by_slug(user, workspace.slug)
      assert %Workspace{} = result
      assert result.id == workspace.id
    end

    test "returns nil when user is not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()

      assert MembershipRepository.get_workspace_for_user_by_slug(non_member, workspace.slug) ==
               nil
    end
  end

  describe "get_workspace_and_member_by_slug/2" do
    test "returns workspace and member tuple" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = MembershipRepository.get_workspace_and_member_by_slug(user, workspace.slug)
      assert {%Workspace{}, %WorkspaceMember{}} = result

      {ws, member} = result
      assert ws.id == workspace.id
      assert member.user_id == user.id
    end

    test "returns nil for non-member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()

      assert MembershipRepository.get_workspace_and_member_by_slug(non_member, workspace.slug) ==
               nil
    end
  end

  describe "workspace_exists?/1" do
    test "returns true when workspace exists" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.workspace_exists?(workspace.id) == true
    end

    test "returns false when workspace doesn't exist" do
      assert MembershipRepository.workspace_exists?(Ecto.UUID.generate()) == false
    end
  end

  describe "get_member/2" do
    test "returns member record" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = MembershipRepository.get_member(user, workspace.id)
      assert %WorkspaceMember{} = result
      assert result.role == :owner
    end

    test "returns nil when not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()

      assert MembershipRepository.get_member(non_member, workspace.id) == nil
    end
  end

  describe "find_member_by_email/2" do
    test "finds member case-insensitively" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()
      add_workspace_member_fixture(workspace.id, member, :admin)

      result = MembershipRepository.find_member_by_email(workspace.id, member.email)
      assert %WorkspaceMember{} = result
      assert result.email == member.email
    end

    test "returns nil when email not found" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.find_member_by_email(workspace.id, "nonexistent@example.com") ==
               nil
    end

    test "is case-insensitive" do
      owner = user_fixture(%{email: "Owner@Example.Com"})
      workspace = workspace_fixture(owner)

      result =
        MembershipRepository.find_member_by_email(workspace.id, "owner@example.com")

      assert result != nil
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
    test "returns all members as domain entities" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()
      add_workspace_member_fixture(workspace.id, member, :admin)

      members = MembershipRepository.list_members(workspace.id)

      assert length(members) == 2
      assert Enum.all?(members, &match?(%WorkspaceMember{}, &1))
    end

    test "returns empty list when no members" do
      assert MembershipRepository.list_members(Ecto.UUID.generate()) == []
    end
  end

  describe "slug_exists?/2" do
    test "returns true when slug exists" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.slug_exists?(workspace.slug) == true
    end

    test "returns false when slug doesn't exist" do
      assert MembershipRepository.slug_exists?("non-existent-slug") == false
    end

    test "excludes workspace by id when excluding_id given" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.slug_exists?(workspace.slug, workspace.id) == false
    end
  end

  describe "create_member/1" do
    test "creates workspace member" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      new_user = user_fixture()

      {:ok, member} =
        MembershipRepository.create_member(%{
          workspace_id: workspace.id,
          user_id: new_user.id,
          email: new_user.email,
          role: :member
        })

      assert %WorkspaceMember{} = member
      assert member.workspace_id == workspace.id
      assert member.email == new_user.email
    end

    test "returns error for invalid attrs" do
      {:error, %Ecto.Changeset{}} = MembershipRepository.create_member(%{})
    end
  end

  describe "update_member/2" do
    test "updates member fields" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      member_user = user_fixture()
      member = add_workspace_member_fixture(workspace.id, member_user, :member)

      {:ok, updated} = MembershipRepository.update_member(member, %{role: :admin})
      assert updated.role == :admin
    end
  end

  describe "delete_member/1" do
    test "removes member" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      member_user = user_fixture()
      member = add_workspace_member_fixture(workspace.id, member_user, :member)

      {:ok, _deleted} = MembershipRepository.delete_member(member)
      assert MembershipRepository.get_member(member_user, workspace.id) == nil
    end
  end

  describe "member?/2" do
    test "returns true for member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.member?(user.id, workspace.id) == true
    end

    test "returns false for non-member" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      non_member = user_fixture()

      assert MembershipRepository.member?(non_member.id, workspace.id) == false
    end
  end

  describe "member_by_slug?/2" do
    test "returns true for member by slug" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert MembershipRepository.member_by_slug?(user.id, workspace.slug) == true
    end

    test "returns false for non-member by slug" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      non_member = user_fixture()

      assert MembershipRepository.member_by_slug?(non_member.id, workspace.slug) == false
    end
  end

  describe "transact/1" do
    test "wraps operations in transaction" do
      result =
        MembershipRepository.transact(fn ->
          {:ok, :success}
        end)

      assert {:ok, :success} = result
    end
  end
end
