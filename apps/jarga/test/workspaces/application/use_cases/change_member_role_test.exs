defmodule Jarga.Workspaces.UseCases.ChangeMemberRoleTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Application.UseCases.ChangeMemberRole
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_existing_user(_user, _workspace, _inviter), do: :ok
    def notify_new_user(_email, _workspace, _inviter), do: :ok
  end

  describe "execute/2 - successful role change" do
    test "changes member role from admin to member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # First add member as admin (and accept invitation)
      {:ok, _member} =
        invite_and_accept_member(owner, workspace.id, member.email, :admin)

      # Change role to member
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email,
        new_role: :member
      }

      assert {:ok, updated_member} = ChangeMemberRole.execute(params, [])
      assert updated_member.role == :member
      assert updated_member.user_id == member.id
    end

    test "changes member role from member to guest" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # Add member (and accept invitation)
      {:ok, _member} =
        invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Change to guest
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email,
        new_role: :guest
      }

      assert {:ok, updated_member} = ChangeMemberRole.execute(params, [])
      assert updated_member.role == :guest
    end

    test "changes member role from guest to admin" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # Add as guest (and accept invitation)
      {:ok, _member} =
        invite_and_accept_member(owner, workspace.id, member.email, :guest)

      # Change to admin
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email,
        new_role: :admin
      }

      assert {:ok, updated_member} = ChangeMemberRole.execute(params, [])
      assert updated_member.role == :admin
    end
  end

  describe "execute/2 - validation errors" do
    test "returns error when trying to change to owner role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      {:ok, _member} =
        invite_and_accept_member(owner, workspace.id, member.email, :member)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email,
        new_role: :owner
      }

      assert {:error, :invalid_role} = ChangeMemberRole.execute(params, [])
    end

    test "returns error when trying to change owner's role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: owner.email,
        new_role: :admin
      }

      assert {:error, :cannot_change_owner_role} = ChangeMemberRole.execute(params, [])
    end

    test "returns error when actor is not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      member = user_fixture()

      {:ok, _member} =
        invite_and_accept_member(owner, workspace.id, member.email, :member)

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        member_email: member.email,
        new_role: :admin
      }

      assert {:error, :unauthorized} = ChangeMemberRole.execute(params, [])
    end

    test "returns error when member not found" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: "nonexistent@example.com",
        new_role: :admin
      }

      assert {:error, :member_not_found} = ChangeMemberRole.execute(params, [])
    end

    test "returns error when workspace not found" do
      owner = user_fixture()
      member = user_fixture()

      params = %{
        actor: owner,
        workspace_id: Ecto.UUID.generate(),
        member_email: member.email,
        new_role: :admin
      }

      assert {:error, :workspace_not_found} = ChangeMemberRole.execute(params, [])
    end
  end
end
