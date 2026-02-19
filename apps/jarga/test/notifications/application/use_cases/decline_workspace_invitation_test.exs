defmodule Jarga.Notifications.Application.UseCases.DeclineWorkspaceInvitationTest do
  @moduledoc """
  Tests for event emission in DeclineWorkspaceInvitation use case.
  """
  use Jarga.DataCase, async: false

  alias Jarga.Notifications.Application.UseCases.DeclineWorkspaceInvitation
  alias Jarga.Notifications.Domain.Events.NotificationActionTaken
  alias Perme8.Events.TestEventBus

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.NotificationsFixtures

  describe "execute/3 - event emission" do
    test "emits NotificationActionTaken event with action=declined" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      invitee = user_fixture()
      workspace = workspace_fixture(owner)

      # Create a pending invitation
      {:ok, {:invitation_sent, _invitation}} =
        Identity.invite_member(owner, workspace.id, invitee.email, :member)

      # Create notification for the invitation
      notification =
        notification_fixture(invitee, %{
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: owner.email,
          role: "member"
        })

      assert {:ok, _notification} =
               DeclineWorkspaceInvitation.execute(notification.id, invitee.id,
                 event_bus: TestEventBus
               )

      assert [%NotificationActionTaken{} = event] = TestEventBus.get_events()
      assert event.notification_id == notification.id
      assert event.user_id == invitee.id
      assert event.action == "declined"
      assert event.aggregate_id == notification.id
      assert event.actor_id == invitee.id
      assert event.workspace_id == workspace.id
    end

    test "does not emit event when notification not found" do
      ensure_test_event_bus_started()

      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               DeclineWorkspaceInvitation.execute(fake_id, user.id, event_bus: TestEventBus)

      assert [] = TestEventBus.get_events()
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(TestEventBus) do
      nil ->
        {:ok, _pid} = TestEventBus.start_link([])
        :ok

      _pid ->
        TestEventBus.reset()
    end
  end
end
