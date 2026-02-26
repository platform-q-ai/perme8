defmodule Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriberTest do
  use Notifications.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Identity.Domain.Events.MemberInvited
  alias Notifications.Domain.Events.NotificationCreated
  alias Notifications.Infrastructure.Repositories.NotificationRepository
  alias Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber

  import Notifications.Test.Fixtures.AccountsFixtures

  describe "subscriptions/0" do
    test "returns the workspace member events topic" do
      assert WorkspaceInvitationSubscriber.subscriptions() == [
               "events:identity:workspace_member"
             ]
    end
  end

  describe "handle_event/1" do
    test "creates notification when MemberInvited event is received" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      user = user_fixture()
      workspace_id = Ecto.UUID.generate()

      event =
        MemberInvited.new(%{
          aggregate_id: "#{workspace_id}:#{user.id}",
          actor_id: Ecto.UUID.generate(),
          user_id: user.id,
          workspace_id: workspace_id,
          workspace_name: "Test Workspace",
          invited_by_name: "Test Inviter",
          role: "member"
        })

      # Send structured event (EventHandler routes structs to handle_event/1)
      send(pid, event)

      # Synchronize with the GenServer mailbox instead of sleeping
      :sys.get_state(pid)

      notifications = NotificationRepository.list_by_user(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.type == "workspace_invitation"
      assert notification.data["workspace_id"] == workspace_id
      assert notification.data["workspace_name"] == "Test Workspace"
      assert notification.data["invited_by_name"] == "Test Inviter"
      assert notification.data["role"] == "member"
    end

    test "ignores non-MemberInvited events" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      user = user_fixture()

      # Send a different event struct
      event =
        NotificationCreated.new(%{
          aggregate_id: Ecto.UUID.generate(),
          actor_id: Ecto.UUID.generate(),
          notification_id: Ecto.UUID.generate(),
          user_id: user.id,
          type: "test"
        })

      send(pid, event)

      # Synchronize with the GenServer mailbox instead of sleeping
      :sys.get_state(pid)

      # No notification should be created
      notifications = NotificationRepository.list_by_user(user.id)
      assert notifications == []
    end

    test "handles unknown non-struct messages gracefully" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      send(pid, {:unknown_event, %{}})

      # Synchronize with the GenServer mailbox instead of sleeping
      :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end
end
