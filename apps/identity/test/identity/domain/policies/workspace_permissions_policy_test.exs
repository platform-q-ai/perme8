defmodule Identity.Domain.Policies.WorkspacePermissionsPolicyTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Policies.WorkspacePermissionsPolicy

  describe ":view_workspace" do
    test "guest can view workspace" do
      assert WorkspacePermissionsPolicy.can?(:guest, :view_workspace)
    end

    test "member can view workspace" do
      assert WorkspacePermissionsPolicy.can?(:member, :view_workspace)
    end

    test "admin can view workspace" do
      assert WorkspacePermissionsPolicy.can?(:admin, :view_workspace)
    end

    test "owner can view workspace" do
      assert WorkspacePermissionsPolicy.can?(:owner, :view_workspace)
    end
  end

  describe ":edit_workspace" do
    test "guest cannot edit workspace" do
      refute WorkspacePermissionsPolicy.can?(:guest, :edit_workspace)
    end

    test "member cannot edit workspace" do
      refute WorkspacePermissionsPolicy.can?(:member, :edit_workspace)
    end

    test "admin can edit workspace" do
      assert WorkspacePermissionsPolicy.can?(:admin, :edit_workspace)
    end

    test "owner can edit workspace" do
      assert WorkspacePermissionsPolicy.can?(:owner, :edit_workspace)
    end
  end

  describe ":delete_workspace" do
    test "guest cannot delete workspace" do
      refute WorkspacePermissionsPolicy.can?(:guest, :delete_workspace)
    end

    test "member cannot delete workspace" do
      refute WorkspacePermissionsPolicy.can?(:member, :delete_workspace)
    end

    test "admin cannot delete workspace" do
      refute WorkspacePermissionsPolicy.can?(:admin, :delete_workspace)
    end

    test "owner can delete workspace" do
      assert WorkspacePermissionsPolicy.can?(:owner, :delete_workspace)
    end
  end

  describe ":invite_member" do
    test "guest cannot invite member" do
      refute WorkspacePermissionsPolicy.can?(:guest, :invite_member)
    end

    test "member cannot invite member" do
      refute WorkspacePermissionsPolicy.can?(:member, :invite_member)
    end

    test "admin can invite member" do
      assert WorkspacePermissionsPolicy.can?(:admin, :invite_member)
    end

    test "owner can invite member" do
      assert WorkspacePermissionsPolicy.can?(:owner, :invite_member)
    end
  end

  describe "default deny" do
    test "returns false for unknown actions" do
      refute WorkspacePermissionsPolicy.can?(:owner, :unknown_action)
      refute WorkspacePermissionsPolicy.can?(:admin, :fly_to_moon)
      refute WorkspacePermissionsPolicy.can?(:guest, :create_project)
    end
  end
end
