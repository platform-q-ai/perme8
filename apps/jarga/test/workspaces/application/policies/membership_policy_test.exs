defmodule Jarga.Workspaces.Policies.MembershipPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Workspaces.Application.Policies.MembershipPolicy

  describe "valid_invitation_role?/1" do
    test "returns true for allowed invitation roles" do
      assert MembershipPolicy.valid_invitation_role?(:admin)
      assert MembershipPolicy.valid_invitation_role?(:member)
      assert MembershipPolicy.valid_invitation_role?(:guest)
    end

    test "returns false for owner role" do
      refute MembershipPolicy.valid_invitation_role?(:owner)
    end

    test "returns false for invalid roles" do
      refute MembershipPolicy.valid_invitation_role?(:invalid)
      refute MembershipPolicy.valid_invitation_role?(:moderator)
    end
  end

  describe "valid_role_change?/1" do
    test "returns true for allowed role changes" do
      assert MembershipPolicy.valid_role_change?(:admin)
      assert MembershipPolicy.valid_role_change?(:member)
      assert MembershipPolicy.valid_role_change?(:guest)
    end

    test "returns false for owner role" do
      refute MembershipPolicy.valid_role_change?(:owner)
    end

    test "returns false for invalid roles" do
      refute MembershipPolicy.valid_role_change?(:invalid)
    end
  end

  describe "can_change_role?/1" do
    test "returns false for owner role (protected)" do
      refute MembershipPolicy.can_change_role?(:owner)
    end

    test "returns true for non-protected roles" do
      assert MembershipPolicy.can_change_role?(:admin)
      assert MembershipPolicy.can_change_role?(:member)
      assert MembershipPolicy.can_change_role?(:guest)
    end
  end

  describe "can_remove_member?/1" do
    test "returns false for owner role (protected)" do
      refute MembershipPolicy.can_remove_member?(:owner)
    end

    test "returns true for non-protected roles" do
      assert MembershipPolicy.can_remove_member?(:admin)
      assert MembershipPolicy.can_remove_member?(:member)
      assert MembershipPolicy.can_remove_member?(:guest)
    end
  end

  describe "allowed_invitation_roles/0" do
    test "returns list of allowed invitation roles" do
      assert MembershipPolicy.allowed_invitation_roles() == [:admin, :member, :guest]
    end
  end

  describe "protected_roles/0" do
    test "returns list of protected roles" do
      assert MembershipPolicy.protected_roles() == [:owner]
    end
  end
end
