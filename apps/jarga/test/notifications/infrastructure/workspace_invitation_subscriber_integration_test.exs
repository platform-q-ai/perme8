defmodule Jarga.Notifications.Infrastructure.WorkspaceInvitationSubscriberIntegrationTest do
  use Jarga.DataCase, async: false

  import Jarga.AccountsFixtures

  alias Identity.Domain.Events.MemberInvited
  alias Jarga.Notifications
  alias Perme8.Events.EventBus

  @moduletag :integration

  describe "WorkspaceInvitationSubscriber integration" do
    test "creates exactly one notification when MemberInvited is emitted via EventBus" do
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

      # Emit via the real EventBus — this broadcasts to:
      # 1. events:identity (structured context topic)
      # 2. events:identity:workspace_member (structured aggregate topic)
      # 3. events:workspace:<id> (workspace-scoped topic)
      # 4. workspace_invitations (legacy bridge translation)
      #
      # The subscriber listens on events:identity:workspace_member only
      # (single topic to avoid duplicate delivery).
      # No one listens on "workspace_invitations" anymore (subscriber was converted).
      EventBus.emit(event)

      # Wait for async processing
      :timer.sleep(200)

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.type == "workspace_invitation"
      assert notification.data["workspace_id"] == workspace_id
      assert notification.data["workspace_name"] == "Test Workspace"
      assert notification.data["invited_by_name"] == "Test Inviter"
    end
  end
end
