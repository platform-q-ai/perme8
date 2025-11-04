defmodule Jarga.Workspaces.UseCases.RemoveMemberTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.UseCases.{InviteMember, RemoveMember}
  alias Jarga.Workspaces
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_existing_user(_user, _workspace, _inviter), do: :ok
    def notify_new_user(_email, _workspace, _inviter), do: :ok
  end

  describe "execute/2 - successful removal" do
    test "removes a member from workspace" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      member = user_fixture()

      # Add member
      {:ok, {:member_added, _}} =
        InviteMember.execute(
          %{inviter: owner, workspace_id: workspace.id, email: member.email, role: :admin},
          notifier: MockNotifier
        )

      # Verify member exists
      members = Workspaces.list_members(workspace.id)
      assert length(members) == 2

      # Remove member
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:ok, deleted_member} = RemoveMember.execute(params, [])
      assert deleted_member.user_id == member.id

      # Verify member is removed
      members = Workspaces.list_members(workspace.id)
      assert length(members) == 1
      assert hd(members).email == owner.email
    end

    test "removes a pending invitation" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      email = "pending@example.com"

      # Create pending invitation
      {:ok, {:invitation_sent, _}} =
        InviteMember.execute(
          %{inviter: owner, workspace_id: workspace.id, email: email, role: :admin},
          notifier: MockNotifier
        )

      # Verify invitation exists
      members = Workspaces.list_members(workspace.id)
      assert length(members) == 2

      # Remove invitation
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: email
      }

      assert {:ok, deleted_invitation} = RemoveMember.execute(params, [])
      assert deleted_invitation.email == email

      # Verify invitation is removed
      members = Workspaces.list_members(workspace.id)
      assert length(members) == 1
    end
  end

  describe "execute/2 - validation errors" do
    test "returns error when trying to remove owner" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: owner.email
      }

      assert {:error, :cannot_remove_owner} = RemoveMember.execute(params, [])
    end

    test "returns error when actor is not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      member = user_fixture()

      {:ok, {:member_added, _}} =
        InviteMember.execute(
          %{inviter: owner, workspace_id: workspace.id, email: member.email, role: :member},
          notifier: MockNotifier
        )

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        member_email: member.email
      }

      assert {:error, :unauthorized} = RemoveMember.execute(params, [])
    end

    test "returns error when member not found" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        member_email: "nonexistent@example.com"
      }

      assert {:error, :member_not_found} = RemoveMember.execute(params, [])
    end

    test "returns error when workspace not found" do
      owner = user_fixture()
      member = user_fixture()

      params = %{
        actor: owner,
        workspace_id: Ecto.UUID.generate(),
        member_email: member.email
      }

      assert {:error, :workspace_not_found} = RemoveMember.execute(params, [])
    end
  end
end
