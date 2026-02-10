defmodule Jarga.Notifications.Infrastructure.WorkspaceInvitationSubscriberTest do
  use Jarga.DataCase, async: false

  import Jarga.AccountsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Notifications
  alias Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber
  # Use Identity.Repo for all operations to ensure consistent transaction visibility
  alias Identity.Repo, as: Repo

  describe "WorkspaceInvitationSubscriber" do
    test "creates notification when workspace_invitation_created event is received" do
      # Start the subscriber
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])

      # Allow the subscriber to use our test's database connection
      Sandbox.allow(Repo, self(), pid)

      # Create test data
      user = user_fixture()
      workspace_id = Ecto.UUID.generate()

      params = %{
        user_id: user.id,
        workspace_id: workspace_id,
        workspace_name: "Test Workspace",
        invited_by_name: "Test Inviter",
        role: "member"
      }

      # Send the event
      send(pid, {:workspace_invitation_created, params})

      # Wait for async processing
      :timer.sleep(50)

      # Verify notification was created
      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.type == "workspace_invitation"
      assert notification.data["workspace_id"] == workspace_id
      assert notification.data["workspace_name"] == "Test Workspace"
    end

    test "handles unknown messages gracefully" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Repo, self(), pid)

      # Send unknown message
      send(pid, {:unknown_event, %{}})

      # Process should still be alive
      :timer.sleep(10)
      assert Process.alive?(pid)
    end
  end
end
