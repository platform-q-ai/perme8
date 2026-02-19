defmodule Identity.Application.UseCases.CreateNotificationsForPendingInvitationsTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.CreateNotificationsForPendingInvitations
  alias Identity.Domain.Events.MemberInvited
  alias Perme8.Events.TestEventBus

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  defp ensure_test_event_bus_started do
    case TestEventBus.start_link([]) do
      {:ok, pid} -> Process.unlink(pid)
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp events_of_type(type, workspace_id) do
    Enum.filter(TestEventBus.get_events(), fn event ->
      event.__struct__ == type && event.workspace_id == workspace_id
    end)
  end

  defp events_for_user(type, user_id) do
    Enum.filter(TestEventBus.get_events(), fn event ->
      event.__struct__ == type && event.user_id == user_id
    end)
  end

  describe "execute/2" do
    test "finds pending invitations and emits events" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      # Create a pending invitation for the invitee's email
      _invitation =
        pending_invitation_fixture(workspace.id, invitee.email, :admin, invited_by: owner.id)

      params = %{user: invitee}
      opts = [event_bus: TestEventBus]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      assert [%MemberInvited{} = event] = events_of_type(MemberInvited, workspace.id)
      assert event.user_id == invitee.id
      assert event.workspace_id == workspace.id
      assert event.workspace_name == workspace.name
      assert event.role == "admin"
    end

    test "no pending invitations returns {:ok, []}" do
      ensure_test_event_bus_started()

      user = user_fixture()

      params = %{user: user}
      opts = [event_bus: TestEventBus]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      assert [] = events_for_user(MemberInvited, user.id)
    end

    test "emits MemberInvited events via event_bus for each pending invitation" do
      ensure_test_event_bus_started()
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      # Create a pending invitation for the invitee's email
      _invitation =
        pending_invitation_fixture(workspace.id, invitee.email, :admin, invited_by: owner.id)

      params = %{user: invitee}
      opts = [event_bus: TestEventBus]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      assert [%MemberInvited{} = event] = events_of_type(MemberInvited, workspace.id)
      assert event.user_id == invitee.id
      assert event.workspace_id == workspace.id
      assert event.workspace_name == workspace.name
      assert event.role == "admin"
      assert event.invited_by_name != nil
    end

    test "does not emit events when no pending invitations" do
      ensure_test_event_bus_started()
      user = user_fixture()

      params = %{user: user}
      opts = [event_bus: TestEventBus]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      assert [] = events_for_user(MemberInvited, user.id)
    end
  end
end
