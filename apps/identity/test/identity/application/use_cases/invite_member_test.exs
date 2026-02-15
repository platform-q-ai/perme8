defmodule Identity.Application.UseCases.InviteMemberTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.InviteMember
  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_existing_user(_user, _workspace, _inviter), do: :ok
    def notify_new_user(_email, _workspace, _inviter), do: :ok
  end

  describe "execute/2 - existing user" do
    test "creates pending invitation for existing user (requires acceptance)" do
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

      assert {:ok, {:invitation_sent, invitation}} = InviteMember.execute(params, opts)
      assert invitation.email == invitee.email
      assert invitation.role == :admin
      assert invitation.user_id == nil
      assert invitation.joined_at == nil
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
      assert {:ok, {:invitation_sent, _}} = InviteMember.execute(params, opts)

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

    test "returns error when workspace not found" do
      owner = user_fixture()
      invitee = user_fixture()

      params = %{
        inviter: owner,
        workspace_id: Ecto.UUID.generate(),
        email: invitee.email,
        role: :admin
      }

      assert {:error, :workspace_not_found} = InviteMember.execute(params, [])
    end

    test "returns error when inviter lacks permission (guest role)" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      guest = user_fixture()
      invitee = user_fixture()

      # Add guest as a member directly
      _member = add_workspace_member_fixture(workspace.id, guest, :guest)

      params = %{
        inviter: guest,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :member
      }

      assert {:error, :forbidden} = InviteMember.execute(params, [])
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
      _invitee = user_fixture(%{email: "User@Example.Com"})

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: "user@example.com",
        role: :admin
      }

      opts = [notifier: MockNotifier]

      assert {:ok, {:invitation_sent, invitation}} = InviteMember.execute(params, opts)
      assert invitation.email == "user@example.com"
    end
  end
end
