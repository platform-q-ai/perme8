defmodule Jarga.Domain.Policies.DomainPermissionsPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Domain.Policies.DomainPermissionsPolicy

  # ── Project permissions ──────────────────────────────────────────────

  describe "project permissions - viewing" do
    test "guest can view projects" do
      assert DomainPermissionsPolicy.can?(:guest, :view_project)
    end

    test "member can view projects" do
      assert DomainPermissionsPolicy.can?(:member, :view_project)
    end

    test "admin can view projects" do
      assert DomainPermissionsPolicy.can?(:admin, :view_project)
    end

    test "owner can view projects" do
      assert DomainPermissionsPolicy.can?(:owner, :view_project)
    end
  end

  describe "project permissions - creating" do
    test "guest cannot create project" do
      refute DomainPermissionsPolicy.can?(:guest, :create_project)
    end

    test "member can create project" do
      assert DomainPermissionsPolicy.can?(:member, :create_project)
    end

    test "admin can create project" do
      assert DomainPermissionsPolicy.can?(:admin, :create_project)
    end

    test "owner can create project" do
      assert DomainPermissionsPolicy.can?(:owner, :create_project)
    end
  end

  describe "project permissions - editing own project" do
    test "guest cannot edit own project" do
      refute DomainPermissionsPolicy.can?(:guest, :edit_project, owns_resource: true)
    end

    test "member can edit own project" do
      assert DomainPermissionsPolicy.can?(:member, :edit_project, owns_resource: true)
    end

    test "admin can edit own project" do
      assert DomainPermissionsPolicy.can?(:admin, :edit_project, owns_resource: true)
    end

    test "owner can edit own project" do
      assert DomainPermissionsPolicy.can?(:owner, :edit_project, owns_resource: true)
    end
  end

  describe "project permissions - editing others' project" do
    test "guest cannot edit others' project" do
      refute DomainPermissionsPolicy.can?(:guest, :edit_project, owns_resource: false)
    end

    test "member cannot edit others' project" do
      refute DomainPermissionsPolicy.can?(:member, :edit_project, owns_resource: false)
    end

    test "admin can edit others' project" do
      assert DomainPermissionsPolicy.can?(:admin, :edit_project, owns_resource: false)
    end

    test "owner can edit others' project" do
      assert DomainPermissionsPolicy.can?(:owner, :edit_project, owns_resource: false)
    end
  end

  describe "project permissions - deleting own project" do
    test "guest cannot delete own project" do
      refute DomainPermissionsPolicy.can?(:guest, :delete_project, owns_resource: true)
    end

    test "member can delete own project" do
      assert DomainPermissionsPolicy.can?(:member, :delete_project, owns_resource: true)
    end

    test "admin can delete own project" do
      assert DomainPermissionsPolicy.can?(:admin, :delete_project, owns_resource: true)
    end

    test "owner can delete own project" do
      assert DomainPermissionsPolicy.can?(:owner, :delete_project, owns_resource: true)
    end
  end

  describe "project permissions - deleting others' project" do
    test "guest cannot delete others' project" do
      refute DomainPermissionsPolicy.can?(:guest, :delete_project, owns_resource: false)
    end

    test "member cannot delete others' project" do
      refute DomainPermissionsPolicy.can?(:member, :delete_project, owns_resource: false)
    end

    test "admin can delete others' project" do
      assert DomainPermissionsPolicy.can?(:admin, :delete_project, owns_resource: false)
    end

    test "owner can delete others' project" do
      assert DomainPermissionsPolicy.can?(:owner, :delete_project, owns_resource: false)
    end
  end

  # ── Document permissions ─────────────────────────────────────────────

  describe "document permissions - viewing" do
    test "guest can view document" do
      assert DomainPermissionsPolicy.can?(:guest, :view_document)
    end

    test "member can view document" do
      assert DomainPermissionsPolicy.can?(:member, :view_document)
    end

    test "admin can view document" do
      assert DomainPermissionsPolicy.can?(:admin, :view_document)
    end

    test "owner can view document" do
      assert DomainPermissionsPolicy.can?(:owner, :view_document)
    end
  end

  describe "document permissions - creating" do
    test "guest cannot create document" do
      refute DomainPermissionsPolicy.can?(:guest, :create_document)
    end

    test "member can create document" do
      assert DomainPermissionsPolicy.can?(:member, :create_document)
    end

    test "admin can create document" do
      assert DomainPermissionsPolicy.can?(:admin, :create_document)
    end

    test "owner can create document" do
      assert DomainPermissionsPolicy.can?(:owner, :create_document)
    end
  end

  describe "document permissions - editing own document" do
    test "guest cannot edit own document" do
      refute DomainPermissionsPolicy.can?(:guest, :edit_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "member can edit own document" do
      assert DomainPermissionsPolicy.can?(:member, :edit_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "admin can edit own document" do
      assert DomainPermissionsPolicy.can?(:admin, :edit_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "owner can edit own document" do
      assert DomainPermissionsPolicy.can?(:owner, :edit_document,
               owns_resource: true,
               is_public: false
             )
    end
  end

  describe "document permissions - editing shared (public) document" do
    test "guest cannot edit shared document" do
      refute DomainPermissionsPolicy.can?(:guest, :edit_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "member can edit shared document" do
      assert DomainPermissionsPolicy.can?(:member, :edit_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "admin can edit shared document" do
      assert DomainPermissionsPolicy.can?(:admin, :edit_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "owner cannot edit shared document they don't own" do
      refute DomainPermissionsPolicy.can?(:owner, :edit_document,
               owns_resource: false,
               is_public: true
             )
    end
  end

  describe "document permissions - editing others' non-public document" do
    test "guest cannot edit others' non-public document" do
      refute DomainPermissionsPolicy.can?(:guest, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "member cannot edit others' non-public document" do
      refute DomainPermissionsPolicy.can?(:member, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "admin cannot edit others' non-public document" do
      refute DomainPermissionsPolicy.can?(:admin, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "owner cannot edit others' non-public document" do
      refute DomainPermissionsPolicy.can?(:owner, :edit_document,
               owns_resource: false,
               is_public: false
             )
    end
  end

  describe "document permissions - deleting own document" do
    test "guest cannot delete own document" do
      refute DomainPermissionsPolicy.can?(:guest, :delete_document, owns_resource: true)
    end

    test "member can delete own document" do
      assert DomainPermissionsPolicy.can?(:member, :delete_document, owns_resource: true)
    end

    test "admin can delete own document" do
      assert DomainPermissionsPolicy.can?(:admin, :delete_document, owns_resource: true)
    end

    test "owner can delete own document" do
      assert DomainPermissionsPolicy.can?(:owner, :delete_document, owns_resource: true)
    end
  end

  describe "document permissions - deleting others' shared document" do
    test "guest cannot delete others' shared document" do
      refute DomainPermissionsPolicy.can?(:guest, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "member cannot delete others' shared document" do
      refute DomainPermissionsPolicy.can?(:member, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "admin can delete others' shared document" do
      assert DomainPermissionsPolicy.can?(:admin, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "owner cannot delete others' shared document" do
      refute DomainPermissionsPolicy.can?(:owner, :delete_document,
               owns_resource: false,
               is_public: true
             )
    end
  end

  describe "document permissions - deleting others' non-shared document" do
    test "guest cannot delete others' non-shared document" do
      refute DomainPermissionsPolicy.can?(:guest, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "member cannot delete others' non-shared document" do
      refute DomainPermissionsPolicy.can?(:member, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "admin cannot delete others' non-shared document" do
      refute DomainPermissionsPolicy.can?(:admin, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "owner cannot delete others' non-shared document" do
      refute DomainPermissionsPolicy.can?(:owner, :delete_document,
               owns_resource: false,
               is_public: false
             )
    end
  end

  describe "document permissions - pinning own document" do
    test "guest cannot pin own document" do
      refute DomainPermissionsPolicy.can?(:guest, :pin_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "member can pin own document" do
      assert DomainPermissionsPolicy.can?(:member, :pin_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "admin can pin own document" do
      assert DomainPermissionsPolicy.can?(:admin, :pin_document,
               owns_resource: true,
               is_public: false
             )
    end

    test "owner can pin own document" do
      assert DomainPermissionsPolicy.can?(:owner, :pin_document,
               owns_resource: true,
               is_public: false
             )
    end
  end

  describe "document permissions - pinning shared (public) document" do
    test "guest cannot pin shared document" do
      refute DomainPermissionsPolicy.can?(:guest, :pin_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "member can pin shared document" do
      assert DomainPermissionsPolicy.can?(:member, :pin_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "admin can pin shared document" do
      assert DomainPermissionsPolicy.can?(:admin, :pin_document,
               owns_resource: false,
               is_public: true
             )
    end

    test "owner can pin shared document" do
      assert DomainPermissionsPolicy.can?(:owner, :pin_document,
               owns_resource: false,
               is_public: true
             )
    end
  end

  describe "document permissions - pinning others' non-public document" do
    test "guest cannot pin others' non-public document" do
      refute DomainPermissionsPolicy.can?(:guest, :pin_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "member cannot pin others' non-public document" do
      refute DomainPermissionsPolicy.can?(:member, :pin_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "admin cannot pin others' non-public document" do
      refute DomainPermissionsPolicy.can?(:admin, :pin_document,
               owns_resource: false,
               is_public: false
             )
    end

    test "owner cannot pin others' non-public document" do
      refute DomainPermissionsPolicy.can?(:owner, :pin_document,
               owns_resource: false,
               is_public: false
             )
    end
  end

  # ── Default deny ─────────────────────────────────────────────────────

  describe "default deny" do
    test "returns false for unknown actions" do
      refute DomainPermissionsPolicy.can?(:owner, :unknown_action)
      refute DomainPermissionsPolicy.can?(:admin, :fly_to_moon)
    end

    test "returns false for workspace-level actions (those belong to WorkspacePermissionsPolicy)" do
      # These actions are NOT handled by DomainPermissionsPolicy
      refute DomainPermissionsPolicy.can?(:owner, :view_workspace)
      refute DomainPermissionsPolicy.can?(:admin, :edit_workspace)
      refute DomainPermissionsPolicy.can?(:owner, :delete_workspace)
      refute DomainPermissionsPolicy.can?(:admin, :invite_member)
    end
  end
end
