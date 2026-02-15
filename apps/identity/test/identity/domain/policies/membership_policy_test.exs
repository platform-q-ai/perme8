defmodule Identity.Domain.Policies.MembershipPolicyTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Policies.MembershipPolicy

  describe "valid_invitation_role?/1" do
    test "returns true for :admin" do
      assert MembershipPolicy.valid_invitation_role?(:admin)
    end

    test "returns true for :member" do
      assert MembershipPolicy.valid_invitation_role?(:member)
    end

    test "returns true for :guest" do
      assert MembershipPolicy.valid_invitation_role?(:guest)
    end

    test "returns false for :owner" do
      refute MembershipPolicy.valid_invitation_role?(:owner)
    end

    test "returns false for invalid roles" do
      refute MembershipPolicy.valid_invitation_role?(:invalid)
      refute MembershipPolicy.valid_invitation_role?(:moderator)
    end
  end

  describe "valid_role_change?/1" do
    test "returns true for :admin" do
      assert MembershipPolicy.valid_role_change?(:admin)
    end

    test "returns true for :member" do
      assert MembershipPolicy.valid_role_change?(:member)
    end

    test "returns true for :guest" do
      assert MembershipPolicy.valid_role_change?(:guest)
    end

    test "returns false for :owner" do
      refute MembershipPolicy.valid_role_change?(:owner)
    end

    test "returns false for invalid roles" do
      refute MembershipPolicy.valid_role_change?(:invalid)
    end
  end

  describe "can_change_role?/1" do
    test "returns false for :owner (protected)" do
      refute MembershipPolicy.can_change_role?(:owner)
    end

    test "returns true for :admin" do
      assert MembershipPolicy.can_change_role?(:admin)
    end

    test "returns true for :member" do
      assert MembershipPolicy.can_change_role?(:member)
    end

    test "returns true for :guest" do
      assert MembershipPolicy.can_change_role?(:guest)
    end
  end

  describe "can_remove_member?/1" do
    test "returns false for :owner (protected)" do
      refute MembershipPolicy.can_remove_member?(:owner)
    end

    test "returns true for :admin" do
      assert MembershipPolicy.can_remove_member?(:admin)
    end

    test "returns true for :member" do
      assert MembershipPolicy.can_remove_member?(:member)
    end

    test "returns true for :guest" do
      assert MembershipPolicy.can_remove_member?(:guest)
    end
  end

  describe "allowed_invitation_roles/0" do
    test "returns [:admin, :member, :guest]" do
      assert MembershipPolicy.allowed_invitation_roles() == [:admin, :member, :guest]
    end
  end

  describe "protected_roles/0" do
    test "returns [:owner]" do
      assert MembershipPolicy.protected_roles() == [:owner]
    end
  end
end
