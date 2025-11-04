defmodule Jarga.Workspaces.UseCases.InviteMemberTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.UseCases.InviteMember
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_existing_user(_user, _workspace, _inviter), do: :ok
    def notify_new_user(_email, _workspace, _inviter), do: :ok
  end

  describe "execute/2 - existing user" do
    test "invites existing user and sends notifications" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :admin
      }

      opts = [notifier: MockNotifier]

      assert {:ok, {:member_added, member}} = InviteMember.execute(params, opts)
      assert member.user_id == invitee.id
      assert member.role == :admin
      assert member.joined_at != nil
    end

    test "returns error for invalid role" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :owner
      }

      assert {:error, :invalid_role} = InviteMember.execute(params, [])
    end

    test "returns error when user already member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :admin
      }

      opts = [notifier: MockNotifier]

      # First invitation succeeds
      assert {:ok, {:member_added, _}} = InviteMember.execute(params, opts)

      # Second invitation fails
      assert {:error, :already_member} = InviteMember.execute(params, opts)
    end

    test "returns error when inviter not a member" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      non_member = user_fixture()
      invitee = user_fixture()

      params = %{
        inviter: non_member,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :admin
      }

      assert {:error, :unauthorized} = InviteMember.execute(params, [])
    end
  end

  describe "execute/2 - non-existing user" do
    test "creates pending invitation and sends email" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      email = "newuser@example.com"

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: email,
        role: :admin
      }

      opts = [notifier: MockNotifier]

      assert {:ok, {:invitation_sent, invitation}} = InviteMember.execute(params, opts)
      assert invitation.email == email
      assert invitation.user_id == nil
      assert invitation.joined_at == nil
    end

    test "is case-insensitive for email matching" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture(%{email: "User@Example.Com"})

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: "user@example.com",
        role: :admin
      }

      opts = [notifier: MockNotifier]

      assert {:ok, {:member_added, member}} = InviteMember.execute(params, opts)
      assert member.user_id == invitee.id
    end
  end
end
