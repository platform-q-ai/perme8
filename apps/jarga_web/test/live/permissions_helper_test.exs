defmodule JargaWeb.Live.PermissionsHelperTest do
  use ExUnit.Case, async: true

  alias JargaWeb.Live.PermissionsHelper
  alias Jarga.Workspaces.Domain.Entities.WorkspaceMember

  describe "can_edit_workspace?/1" do
    test "returns true for admin member" do
      member = %WorkspaceMember{role: :admin}
      assert PermissionsHelper.can_edit_workspace?(member)
    end

    test "returns true for owner member" do
      member = %WorkspaceMember{role: :owner}
      assert PermissionsHelper.can_edit_workspace?(member)
    end

    test "returns false for regular member" do
      member = %WorkspaceMember{role: :member}
      refute PermissionsHelper.can_edit_workspace?(member)
    end

    test "returns false for guest member" do
      member = %WorkspaceMember{role: :guest}
      refute PermissionsHelper.can_edit_workspace?(member)
    end
  end

  describe "can_delete_workspace?/1" do
    test "returns true for owner member" do
      member = %WorkspaceMember{role: :owner}
      assert PermissionsHelper.can_delete_workspace?(member)
    end

    test "returns false for admin member" do
      member = %WorkspaceMember{role: :admin}
      refute PermissionsHelper.can_delete_workspace?(member)
    end

    test "returns false for regular member" do
      member = %WorkspaceMember{role: :member}
      refute PermissionsHelper.can_delete_workspace?(member)
    end

    test "returns false for guest member" do
      member = %WorkspaceMember{role: :guest}
      refute PermissionsHelper.can_delete_workspace?(member)
    end
  end

  describe "can_create_project?/1" do
    test "returns true for owner member" do
      member = %WorkspaceMember{role: :owner}
      assert PermissionsHelper.can_create_project?(member)
    end

    test "returns true for admin member" do
      member = %WorkspaceMember{role: :admin}
      assert PermissionsHelper.can_create_project?(member)
    end

    test "returns true for regular member" do
      member = %WorkspaceMember{role: :member}
      assert PermissionsHelper.can_create_project?(member)
    end

    test "returns false for guest member" do
      member = %WorkspaceMember{role: :guest}
      refute PermissionsHelper.can_create_project?(member)
    end
  end

  describe "can_edit_project?/3" do
    test "returns true when member owns the project" do
      member = %WorkspaceMember{role: :member}
      project = %{user_id: "user-123"}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_edit_project?(member, project, current_user)
    end

    test "returns false when guest doesn't own the project" do
      member = %WorkspaceMember{role: :guest}
      project = %{user_id: "user-456"}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_edit_project?(member, project, current_user)
    end

    test "returns true when admin doesn't own the project" do
      member = %WorkspaceMember{role: :admin}
      project = %{user_id: "user-456"}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_edit_project?(member, project, current_user)
    end

    test "returns false when regular member doesn't own the project" do
      member = %WorkspaceMember{role: :member}
      project = %{user_id: "user-456"}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_edit_project?(member, project, current_user)
    end
  end

  describe "can_delete_project?/3" do
    test "returns true when member owns the project" do
      member = %WorkspaceMember{role: :member}
      project = %{user_id: "user-123"}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_delete_project?(member, project, current_user)
    end

    test "returns false when guest doesn't own the project" do
      member = %WorkspaceMember{role: :guest}
      project = %{user_id: "user-456"}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_delete_project?(member, project, current_user)
    end

    test "returns true when admin doesn't own the project" do
      member = %WorkspaceMember{role: :admin}
      project = %{user_id: "user-456"}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_delete_project?(member, project, current_user)
    end

    test "returns false when regular member doesn't own the project" do
      member = %WorkspaceMember{role: :member}
      project = %{user_id: "user-456"}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_delete_project?(member, project, current_user)
    end
  end

  describe "can_create_document?/1" do
    test "returns true for owner member" do
      member = %WorkspaceMember{role: :owner}
      assert PermissionsHelper.can_create_document?(member)
    end

    test "returns true for admin member" do
      member = %WorkspaceMember{role: :admin}
      assert PermissionsHelper.can_create_document?(member)
    end

    test "returns true for regular member" do
      member = %WorkspaceMember{role: :member}
      assert PermissionsHelper.can_create_document?(member)
    end

    test "returns false for guest member" do
      member = %WorkspaceMember{role: :guest}
      refute PermissionsHelper.can_create_document?(member)
    end
  end

  describe "can_edit_document?/3" do
    test "returns true when member owns the document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-123", is_public: false}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_edit_document?(member, page, current_user)
    end

    test "returns false when guest doesn't own private document" do
      member = %WorkspaceMember{role: :guest}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_edit_document?(member, page, current_user)
    end

    test "returns true when member can edit public document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-456", is_public: true}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_edit_document?(member, page, current_user)
    end

    test "returns false when regular member doesn't own private document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_edit_document?(member, page, current_user)
    end

    test "returns true when admin can edit public document" do
      member = %WorkspaceMember{role: :admin}
      page = %{user_id: "user-456", is_public: true}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_edit_document?(member, page, current_user)
    end
  end

  describe "can_delete_document?/3" do
    test "returns true when member owns the document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-123", is_public: false}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_delete_document?(member, page, current_user)
    end

    test "returns false when guest doesn't own the document" do
      member = %WorkspaceMember{role: :guest}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_delete_document?(member, page, current_user)
    end

    test "returns true when admin can delete public document" do
      member = %WorkspaceMember{role: :admin}
      page = %{user_id: "user-456", is_public: true}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_delete_document?(member, page, current_user)
    end

    test "returns false when regular member doesn't own the document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_delete_document?(member, page, current_user)
    end

    test "returns false when admin can't delete private document they don't own" do
      member = %WorkspaceMember{role: :admin}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_delete_document?(member, page, current_user)
    end
  end

  describe "can_pin_document?/3" do
    test "returns true when member owns the document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-123", is_public: false}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_pin_document?(member, page, current_user)
    end

    test "returns false when guest doesn't own private document" do
      member = %WorkspaceMember{role: :guest}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_pin_document?(member, page, current_user)
    end

    test "returns true when member can pin public document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-456", is_public: true}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_pin_document?(member, page, current_user)
    end

    test "returns false when regular member doesn't own private document" do
      member = %WorkspaceMember{role: :member}
      page = %{user_id: "user-456", is_public: false}
      current_user = %{id: "user-123"}

      refute PermissionsHelper.can_pin_document?(member, page, current_user)
    end

    test "returns true when admin can pin public document" do
      member = %WorkspaceMember{role: :admin}
      page = %{user_id: "user-456", is_public: true}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_pin_document?(member, page, current_user)
    end

    test "returns true when owner can pin public document" do
      member = %WorkspaceMember{role: :owner}
      page = %{user_id: "user-456", is_public: true}
      current_user = %{id: "user-123"}

      assert PermissionsHelper.can_pin_document?(member, page, current_user)
    end
  end

  describe "can_manage_members?/1" do
    test "returns true for owner member" do
      member = %WorkspaceMember{role: :owner}
      assert PermissionsHelper.can_manage_members?(member)
    end

    test "returns true for admin member" do
      member = %WorkspaceMember{role: :admin}
      assert PermissionsHelper.can_manage_members?(member)
    end

    test "returns false for regular member" do
      member = %WorkspaceMember{role: :member}
      refute PermissionsHelper.can_manage_members?(member)
    end

    test "returns false for guest member" do
      member = %WorkspaceMember{role: :guest}
      refute PermissionsHelper.can_manage_members?(member)
    end
  end
end
