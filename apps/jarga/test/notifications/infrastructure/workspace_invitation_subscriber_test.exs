defmodule Jarga.Notifications.Infrastructure.WorkspaceInvitationSubscriberTest do
  use Jarga.DataCase, async: false

  import Jarga.AccountsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Identity.Domain.Events.MemberInvited
  alias Jarga.Notifications
  alias Jarga.Notifications.Domain.Events.NotificationCreated
  alias Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber
  # Use Identity.Repo for all operations to ensure consistent transaction visibility
  alias Identity.Repo, as: Repo

  describe "WorkspaceInvitationSubscriber" do
    test "creates notification when MemberInvited event is received" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Repo, self(), pid)

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

      :timer.sleep(50)

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.type == "workspace_invitation"
      assert notification.data["workspace_id"] == workspace_id
      assert notification.data["workspace_name"] == "Test Workspace"
    end

    test "ignores non-MemberInvited events" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Repo, self(), pid)

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

      :timer.sleep(50)

      # No notification should be created
      notifications = Notifications.list_notifications(user.id)
      assert notifications == []
    end

    test "handles unknown non-struct messages gracefully" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Repo, self(), pid)

      send(pid, {:unknown_event, %{}})

      :timer.sleep(10)
      assert Process.alive?(pid)
    end
  end
end
