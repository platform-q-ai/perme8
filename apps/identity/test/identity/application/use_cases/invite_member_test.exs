defmodule Identity.Application.UseCases.InviteMemberTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.InviteMember
  alias Identity.Domain.Events.MemberInvited
  alias Perme8.Events.TestEventBus

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  defp ensure_test_event_bus_started do
    case TestEventBus.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> TestEventBus.reset()
    end
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

      opts = [skip_email: true]

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

      opts = [skip_email: true]

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

    test "emits MemberInvited event via event_bus for existing users" do
      ensure_test_event_bus_started()
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :admin
      }

      opts = [skip_email: true, event_bus: TestEventBus]

      assert {:ok, {:invitation_sent, _}} = InviteMember.execute(params, opts)

      events = TestEventBus.get_events()
      assert [%MemberInvited{} = event] = events
      assert event.user_id == invitee.id
      assert event.workspace_id == workspace.id
      assert event.workspace_name == workspace.name
      assert event.role == "admin"
      assert event.invited_by_name != nil
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

      opts = [skip_email: true]

      assert {:ok, {:invitation_sent, invitation}} = InviteMember.execute(params, opts)
      assert invitation.email == email
      assert invitation.user_id == nil
      assert invitation.joined_at == nil
    end

    test "does not emit MemberInvited event for non-existing users" do
      ensure_test_event_bus_started()
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: "nonexistent@example.com",
        role: :member
      }

      opts = [skip_email: true, event_bus: TestEventBus]

      assert {:ok, {:invitation_sent, _}} = InviteMember.execute(params, opts)

      events = TestEventBus.get_events()
      assert events == []
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

      opts = [skip_email: true]

      assert {:ok, {:invitation_sent, invitation}} = InviteMember.execute(params, opts)
      assert invitation.email == "user@example.com"
    end
  end
end
