defmodule Jarga.Workspaces.Policies.PermissionsPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Workspaces.Policies.PermissionsPolicy

  describe "workspace permissions" do
    test "guest can view workspace" do
      assert PermissionsPolicy.can?(:guest, :view_workspace)
    end

    test "member can view workspace" do
      assert PermissionsPolicy.can?(:member, :view_workspace)
    end

    test "admin can view workspace" do
      assert PermissionsPolicy.can?(:admin, :view_workspace)
    end

    test "owner can view workspace" do
      assert PermissionsPolicy.can?(:owner, :view_workspace)
    end

    test "guest cannot edit workspace" do
      refute PermissionsPolicy.can?(:guest, :edit_workspace)
    end

    test "member cannot edit workspace" do
      refute PermissionsPolicy.can?(:member, :edit_workspace)
    end

    test "admin can edit workspace" do
      assert PermissionsPolicy.can?(:admin, :edit_workspace)
    end

    test "owner can edit workspace" do
      assert PermissionsPolicy.can?(:owner, :edit_workspace)
    end

    test "guest cannot delete workspace" do
      refute PermissionsPolicy.can?(:guest, :delete_workspace)
    end

    test "member cannot delete workspace" do
      refute PermissionsPolicy.can?(:member, :delete_workspace)
    end

    test "admin cannot delete workspace" do
      refute PermissionsPolicy.can?(:admin, :delete_workspace)
    end

    test "owner can delete workspace" do
      assert PermissionsPolicy.can?(:owner, :delete_workspace)
    end
  end

  describe "project permissions - viewing" do
    test "guest can view projects" do
      assert PermissionsPolicy.can?(:guest, :view_project)
    end

    test "member can view projects" do
      assert PermissionsPolicy.can?(:member, :view_project)
    end

    test "admin can view projects" do
      assert PermissionsPolicy.can?(:admin, :view_project)
    end

    test "owner can view projects" do
      assert PermissionsPolicy.can?(:owner, :view_project)
    end
  end

  describe "project permissions - creating" do
    test "guest cannot create project" do
      refute PermissionsPolicy.can?(:guest, :create_project)
    end

    test "member can create project" do
      assert PermissionsPolicy.can?(:member, :create_project)
    end

    test "admin can create project" do
      assert PermissionsPolicy.can?(:admin, :create_project)
    end

    test "owner can create project" do
      assert PermissionsPolicy.can?(:owner, :create_project)
    end
  end

  describe "project permissions - editing own project" do
    test "guest cannot edit own project" do
      refute PermissionsPolicy.can?(:guest, :edit_project, owns_resource: true)
    end

    test "member can edit own project" do
      assert PermissionsPolicy.can?(:member, :edit_project, owns_resource: true)
    end

    test "admin can edit own project" do
      assert PermissionsPolicy.can?(:admin, :edit_project, owns_resource: true)
    end

    test "owner can edit own project" do
      assert PermissionsPolicy.can?(:owner, :edit_project, owns_resource: true)
    end
  end

  describe "project permissions - editing others' project" do
    test "guest cannot edit others' project" do
      refute PermissionsPolicy.can?(:guest, :edit_project, owns_resource: false)
    end

    test "member cannot edit others' project" do
      refute PermissionsPolicy.can?(:member, :edit_project, owns_resource: false)
    end

    test "admin can edit others' project" do
      assert PermissionsPolicy.can?(:admin, :edit_project, owns_resource: false)
    end

    test "owner can edit others' project" do
      assert PermissionsPolicy.can?(:owner, :edit_project, owns_resource: false)
    end
  end

  describe "project permissions - deleting own project" do
    test "guest cannot delete own project" do
      refute PermissionsPolicy.can?(:guest, :delete_project, owns_resource: true)
    end

    test "member can delete own project" do
      assert PermissionsPolicy.can?(:member, :delete_project, owns_resource: true)
    end

    test "admin can delete own project" do
      assert PermissionsPolicy.can?(:admin, :delete_project, owns_resource: true)
    end

    test "owner can delete own project" do
      assert PermissionsPolicy.can?(:owner, :delete_project, owns_resource: true)
    end
  end

  describe "project permissions - deleting others' project" do
    test "guest cannot delete others' project" do
      refute PermissionsPolicy.can?(:guest, :delete_project, owns_resource: false)
    end

    test "member cannot delete others' project" do
      refute PermissionsPolicy.can?(:member, :delete_project, owns_resource: false)
    end

    test "admin can delete others' project" do
      assert PermissionsPolicy.can?(:admin, :delete_project, owns_resource: false)
    end

    test "owner can delete others' project" do
      assert PermissionsPolicy.can?(:owner, :delete_project, owns_resource: false)
    end
  end

  describe "page permissions - viewing" do
    test "guest can view pages" do
      assert PermissionsPolicy.can?(:guest, :view_page)
    end

    test "member can view pages" do
      assert PermissionsPolicy.can?(:member, :view_page)
    end

    test "admin can view pages" do
      assert PermissionsPolicy.can?(:admin, :view_page)
    end

    test "owner can view pages" do
      assert PermissionsPolicy.can?(:owner, :view_page)
    end
  end

  describe "page permissions - creating" do
    test "guest cannot create page" do
      refute PermissionsPolicy.can?(:guest, :create_page)
    end

    test "member can create page" do
      assert PermissionsPolicy.can?(:member, :create_page)
    end

    test "admin can create page" do
      assert PermissionsPolicy.can?(:admin, :create_page)
    end

    test "owner can create page" do
      assert PermissionsPolicy.can?(:owner, :create_page)
    end
  end

  describe "page permissions - editing own page" do
    test "guest cannot edit own page" do
      refute PermissionsPolicy.can?(:guest, :edit_page, owns_resource: true, is_public: false)
    end

    test "member can edit own page" do
      assert PermissionsPolicy.can?(:member, :edit_page, owns_resource: true, is_public: false)
    end

    test "admin can edit own page" do
      assert PermissionsPolicy.can?(:admin, :edit_page, owns_resource: true, is_public: false)
    end

    test "owner can edit own page" do
      assert PermissionsPolicy.can?(:owner, :edit_page, owns_resource: true, is_public: false)
    end
  end

  describe "page permissions - editing shared (public) page" do
    test "guest cannot edit shared page" do
      refute PermissionsPolicy.can?(:guest, :edit_page, owns_resource: false, is_public: true)
    end

    test "member can edit shared page" do
      assert PermissionsPolicy.can?(:member, :edit_page, owns_resource: false, is_public: true)
    end

    test "admin can edit shared page" do
      assert PermissionsPolicy.can?(:admin, :edit_page, owns_resource: false, is_public: true)
    end

    test "owner cannot edit shared page they don't own (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :edit_page, owns_resource: false, is_public: true)
    end
  end

  describe "page permissions - editing others' non-public page" do
    test "guest cannot edit others' non-public page" do
      refute PermissionsPolicy.can?(:guest, :edit_page, owns_resource: false, is_public: false)
    end

    test "member cannot edit others' non-public page" do
      refute PermissionsPolicy.can?(:member, :edit_page, owns_resource: false, is_public: false)
    end

    test "admin cannot edit others' non-public page (per requirements)" do
      refute PermissionsPolicy.can?(:admin, :edit_page, owns_resource: false, is_public: false)
    end

    test "owner cannot edit others' non-public page (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :edit_page, owns_resource: false, is_public: false)
    end
  end

  describe "page permissions - deleting own page" do
    test "guest cannot delete own page" do
      refute PermissionsPolicy.can?(:guest, :delete_page, owns_resource: true)
    end

    test "member can delete own page" do
      assert PermissionsPolicy.can?(:member, :delete_page, owns_resource: true)
    end

    test "admin can delete own page" do
      assert PermissionsPolicy.can?(:admin, :delete_page, owns_resource: true)
    end

    test "owner can delete own page" do
      assert PermissionsPolicy.can?(:owner, :delete_page, owns_resource: true)
    end
  end

  describe "page permissions - deleting others' shared page" do
    test "guest cannot delete others' shared page" do
      refute PermissionsPolicy.can?(:guest, :delete_page, owns_resource: false, is_public: true)
    end

    test "member cannot delete others' shared page" do
      refute PermissionsPolicy.can?(:member, :delete_page, owns_resource: false, is_public: true)
    end

    test "admin can delete others' shared page" do
      assert PermissionsPolicy.can?(:admin, :delete_page, owns_resource: false, is_public: true)
    end

    test "owner cannot delete others' shared page (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :delete_page, owns_resource: false, is_public: true)
    end
  end

  describe "page permissions - deleting others' non-shared page" do
    test "guest cannot delete others' non-shared page" do
      refute PermissionsPolicy.can?(:guest, :delete_page, owns_resource: false, is_public: false)
    end

    test "member cannot delete others' non-shared page" do
      refute PermissionsPolicy.can?(:member, :delete_page, owns_resource: false, is_public: false)
    end

    test "admin cannot delete others' non-shared page (per requirements)" do
      refute PermissionsPolicy.can?(:admin, :delete_page, owns_resource: false, is_public: false)
    end

    test "owner cannot delete others' non-shared page (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :delete_page, owns_resource: false, is_public: false)
    end
  end

  describe "page permissions - pinning shared (public) page" do
    test "guest cannot pin shared page" do
      refute PermissionsPolicy.can?(:guest, :pin_page, owns_resource: false, is_public: true)
    end

    test "member can pin shared page" do
      assert PermissionsPolicy.can?(:member, :pin_page, owns_resource: false, is_public: true)
    end

    test "admin can pin shared page" do
      assert PermissionsPolicy.can?(:admin, :pin_page, owns_resource: false, is_public: true)
    end

    test "owner can pin shared page" do
      assert PermissionsPolicy.can?(:owner, :pin_page, owns_resource: false, is_public: true)
    end
  end

  describe "page permissions - pinning own page" do
    test "guest cannot pin own page" do
      refute PermissionsPolicy.can?(:guest, :pin_page, owns_resource: true, is_public: false)
    end

    test "member can pin own page" do
      assert PermissionsPolicy.can?(:member, :pin_page, owns_resource: true, is_public: false)
    end

    test "admin can pin own page" do
      assert PermissionsPolicy.can?(:admin, :pin_page, owns_resource: true, is_public: false)
    end

    test "owner can pin own page" do
      assert PermissionsPolicy.can?(:owner, :pin_page, owns_resource: true, is_public: false)
    end
  end

  describe "page permissions - pinning others' non-public page" do
    test "guest cannot pin others' non-public page" do
      refute PermissionsPolicy.can?(:guest, :pin_page, owns_resource: false, is_public: false)
    end

    test "member cannot pin others' non-public page" do
      refute PermissionsPolicy.can?(:member, :pin_page, owns_resource: false, is_public: false)
    end

    test "admin cannot pin others' non-public page (per requirements)" do
      refute PermissionsPolicy.can?(:admin, :pin_page, owns_resource: false, is_public: false)
    end

    test "owner cannot pin others' non-public page (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :pin_page, owns_resource: false, is_public: false)
    end
  end
end
