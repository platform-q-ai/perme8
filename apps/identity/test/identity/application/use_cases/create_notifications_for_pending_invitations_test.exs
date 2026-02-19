defmodule Identity.Application.UseCases.CreateNotificationsForPendingInvitationsTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.CreateNotificationsForPendingInvitations
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
  end
end
