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

  describe "document permissions - viewing" do
    test "guest can view pages" do
      assert PermissionsPolicy.can?(:guest, :view_document)
    end

    test "member can view pages" do
      assert PermissionsPolicy.can?(:member, :view_document)
    end

    test "admin can view pages" do
      assert PermissionsPolicy.can?(:admin, :view_document)
    end

    test "owner can view pages" do
      assert PermissionsPolicy.can?(:owner, :view_document)
    end
  end

  describe "document permissions - creating" do
    test "guest cannot create document" do
      refute PermissionsPolicy.can?(:guest, :create_document)
    end

    test "member can create document" do
      assert PermissionsPolicy.can?(:member, :create_document)
    end

    test "admin can create document" do
      assert PermissionsPolicy.can?(:admin, :create_document)
    end

    test "owner can create document" do
      assert PermissionsPolicy.can?(:owner, :create_document)
    end
  end

  describe "document permissions - editing own page" do
    test "guest cannot edit own document" do
      refute PermissionsPolicy.can?(:guest, :edit_document, owns_resource: true, is_public: false)
    end

    test "member can edit own document" do
      assert PermissionsPolicy.can?(:member, :edit_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "admin can edit own document" do
      assert PermissionsPolicy.can?(:admin, :edit_document, owns_resource: true, is_public: false)
    end

    test "owner can edit own document" do
      assert PermissionsPolicy.can?(:owner, :edit_document, owns_resource: true, is_public: false)
    end
  end

  describe "document permissions - editing shared (public) page" do
    test "guest cannot edit shared document" do
      refute PermissionsPolicy.can?(:guest, :edit_document, owns_resource: false, is_public: true)
    end

    test "member can edit shared document" do
      assert PermissionsPolicy.can?(:member, :edit_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "admin can edit shared document" do
      assert PermissionsPolicy.can?(:admin, :edit_document, owns_resource: false, is_public: true)
    end

    test "owner cannot edit shared document they don't own (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :edit_document, owns_resource: false, is_public: true)
    end
  end

  describe "document permissions - editing others' non-public document" do
    test "guest cannot edit others' non-public document" do
      refute PermissionsPolicy.can?(:guest, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "member cannot edit others' non-public document" do
      refute PermissionsPolicy.can?(:member, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "admin cannot edit others' non-public document (per requirements)" do
      refute PermissionsPolicy.can?(:admin, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "owner cannot edit others' non-public document (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end
  end

  describe "document permissions - deleting own page" do
    test "guest cannot delete own document" do
      refute PermissionsPolicy.can?(:guest, :delete_document, owns_resource: true)
    end

    test "member can delete own document" do
      assert PermissionsPolicy.can?(:member, :delete_document, owns_resource: true)
    end

    test "admin can delete own document" do
      assert PermissionsPolicy.can?(:admin, :delete_document, owns_resource: true)
    end

    test "owner can delete own document" do
      assert PermissionsPolicy.can?(:owner, :delete_document, owns_resource: true)
    end
  end

  describe "document permissions - deleting others' shared document" do
    test "guest cannot delete others' shared document" do
      refute PermissionsPolicy.can?(:guest, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "member cannot delete others' shared document" do
      refute PermissionsPolicy.can?(:member, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "admin can delete others' shared document" do
      assert PermissionsPolicy.can?(:admin, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "owner cannot delete others' shared document (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end
  end

  describe "document permissions - deleting others' non-shared document" do
    test "guest cannot delete others' non-shared document" do
      refute PermissionsPolicy.can?(:guest, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "member cannot delete others' non-shared document" do
      refute PermissionsPolicy.can?(:member, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "admin cannot delete others' non-shared document (per requirements)" do
      refute PermissionsPolicy.can?(:admin, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "owner cannot delete others' non-shared document (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end
  end

  describe "document permissions - pinning shared (public) page" do
    test "guest cannot pin shared document" do
      refute PermissionsPolicy.can?(:guest, :pin_document, owns_resource: false, is_public: true)
    end

    test "member can pin shared document" do
      assert PermissionsPolicy.can?(:member, :pin_document, owns_resource: false, is_public: true)
    end

    test "admin can pin shared document" do
      assert PermissionsPolicy.can?(:admin, :pin_document, owns_resource: false, is_public: true)
    end

    test "owner can pin shared document" do
      assert PermissionsPolicy.can?(:owner, :pin_document, owns_resource: false, is_public: true)
    end
  end

  describe "document permissions - pinning own page" do
    test "guest cannot pin own document" do
      refute PermissionsPolicy.can?(:guest, :pin_document, owns_resource: true, is_public: false)
    end

    test "member can pin own document" do
      assert PermissionsPolicy.can?(:member, :pin_document, owns_resource: true, is_public: false)
    end

    test "admin can pin own document" do
      assert PermissionsPolicy.can?(:admin, :pin_document, owns_resource: true, is_public: false)
    end

    test "owner can pin own document" do
      assert PermissionsPolicy.can?(:owner, :pin_document, owns_resource: true, is_public: false)
    end
  end

  describe "document permissions - pinning others' non-public document" do
    test "guest cannot pin others' non-public document" do
      refute PermissionsPolicy.can?(:guest, :pin_document, owns_resource: false, is_public: false)
    end

    test "member cannot pin others' non-public document" do
      refute PermissionsPolicy.can?(:member, :pin_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "admin cannot pin others' non-public document (per requirements)" do
      refute PermissionsPolicy.can?(:admin, :pin_document, owns_resource: false, is_public: false)
    end

    test "owner cannot pin others' non-public document (per requirements)" do
      refute PermissionsPolicy.can?(:owner, :pin_document, owns_resource: false, is_public: false)
    end
  end
end
