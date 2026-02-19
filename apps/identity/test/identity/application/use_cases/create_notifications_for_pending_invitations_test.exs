defmodule Identity.Application.UseCases.CreateNotificationsForPendingInvitationsTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.CreateNotificationsForPendingInvitations
  alias Identity.Domain.Events.MemberInvited
  alias Perme8.Events.TestEventBus

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  # Mock PubSub notifier for testing
  defmodule MockPubSubNotifier do
    def broadcast_invitation_created(user_id, workspace_id, workspace_name, inviter_name, role) do
      send(
        self(),
        {:broadcast, user_id, workspace_id, workspace_name, inviter_name, role}
      )

      :ok
    end
  end

  defp ensure_test_event_bus_started do
    case TestEventBus.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> TestEventBus.reset()
    end
  end

  describe "execute/2" do
    test "finds pending invitations and broadcasts PubSub events" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      # Create a pending invitation for the invitee's email
      _invitation =
        pending_invitation_fixture(workspace.id, invitee.email, :admin, invited_by: owner.id)

      params = %{user: invitee}
      opts = [pubsub_notifier: MockPubSubNotifier]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      # Verify broadcast was sent
      assert_receive {:broadcast, user_id, workspace_id, workspace_name, _inviter_name, role}
      assert user_id == invitee.id
      assert workspace_id == workspace.id
      assert workspace_name == workspace.name
      assert role == "admin"
    end

    test "no pending invitations returns {:ok, []}" do
      user = user_fixture()

      params = %{user: user}
      opts = [pubsub_notifier: MockPubSubNotifier]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      # Verify no broadcast was sent
      refute_receive {:broadcast, _, _, _, _, _}, 100
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
      opts = [pubsub_notifier: MockPubSubNotifier, event_bus: TestEventBus]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      events = TestEventBus.get_events()
      assert [%MemberInvited{} = event] = events
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
      opts = [pubsub_notifier: MockPubSubNotifier, event_bus: TestEventBus]

      assert {:ok, []} = CreateNotificationsForPendingInvitations.execute(params, opts)

      events = TestEventBus.get_events()
      assert events == []
    end
  end
end
