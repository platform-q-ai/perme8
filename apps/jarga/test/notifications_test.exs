defmodule Jarga.NotificationsTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.NotificationsFixtures

  describe "accept_workspace_invitation/2" do
    test "marks notification as read when accepting invitation" do
      owner = user_fixture()
      invited_user = user_fixture()
      workspace = workspace_fixture(owner)

      # Create a workspace member invitation (pending)
      {:ok, _workspace_member} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_user.email, :member)

      # Create the notification
      notification =
        notification_fixture(invited_user, %{
          data: %{
            workspace_id: workspace.id,
            workspace_name: workspace.name,
            invited_by_name: owner.email,
            role: "member"
          }
        })

      # Verify notification is not read
      assert notification.read == false
      assert is_nil(notification.read_at)

      # Accept the invitation
      assert {:ok, _workspace_member} =
               Notifications.accept_workspace_invitation(notification.id, invited_user.id)

      # Verify notification is now marked as read
      updated_notification = Notifications.get_notification(notification.id, invited_user.id)

      assert updated_notification.read == true
      assert not is_nil(updated_notification.read_at)
      assert not is_nil(updated_notification.action_taken_at)
    end

    test "accepts invitation and marks action_taken_at" do
      owner = user_fixture()
      invited_user = user_fixture()
      workspace = workspace_fixture(owner)

      # Create a workspace member invitation (pending)
      {:ok, _workspace_member} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_user.email, :member)

      # Create the notification
      notification =
        notification_fixture(invited_user, %{
          data: %{
            workspace_id: workspace.id,
            workspace_name: workspace.name,
            invited_by_name: owner.email,
            role: "member"
          }
        })

      # Accept the invitation
      assert {:ok, workspace_member} =
               Notifications.accept_workspace_invitation(notification.id, invited_user.id)

      assert workspace_member.user_id == invited_user.id
      assert workspace_member.workspace_id == workspace.id
      assert not is_nil(workspace_member.joined_at)

      # Verify action_taken_at is set
      updated_notification = Notifications.get_notification(notification.id, invited_user.id)

      assert not is_nil(updated_notification.action_taken_at)
    end
  end

  describe "decline_workspace_invitation/2" do
    test "marks notification as read when declining invitation" do
      owner = user_fixture()
      invited_user = user_fixture()
      workspace = workspace_fixture(owner)

      # Create a workspace member invitation (pending)
      {:ok, _workspace_member} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_user.email, :member)

      # Create the notification
      notification =
        notification_fixture(invited_user, %{
          data: %{
            workspace_id: workspace.id,
            workspace_name: workspace.name,
            invited_by_name: owner.email,
            role: "member"
          }
        })

      # Verify notification is not read
      assert notification.read == false
      assert is_nil(notification.read_at)

      # Decline the invitation
      assert {:ok, _notification} =
               Notifications.decline_workspace_invitation(notification.id, invited_user.id)

      # Verify notification is now marked as read
      updated_notification = Notifications.get_notification(notification.id, invited_user.id)

      assert updated_notification.read == true
      assert not is_nil(updated_notification.read_at)
      assert not is_nil(updated_notification.action_taken_at)
    end

    test "declines invitation and marks action_taken_at" do
      owner = user_fixture()
      invited_user = user_fixture()
      workspace = workspace_fixture(owner)

      # Create a workspace member invitation (pending)
      {:ok, _workspace_member} =
        Jarga.Workspaces.invite_member(owner, workspace.id, invited_user.email, :member)

      # Create the notification
      notification =
        notification_fixture(invited_user, %{
          data: %{
            workspace_id: workspace.id,
            workspace_name: workspace.name,
            invited_by_name: owner.email,
            role: "member"
          }
        })

      # Decline the invitation
      assert {:ok, updated_notification} =
               Notifications.decline_workspace_invitation(notification.id, invited_user.id)

      assert not is_nil(updated_notification.action_taken_at)

      # Verify workspace member was deleted
      refute Jarga.Repo.get_by(Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema,
               workspace_id: workspace.id,
               user_id: invited_user.id
             )
    end
  end

  describe "get_notification/2" do
    test "retrieves a notification for the user" do
      user = user_fixture()
      notification = notification_fixture(user)

      result = Notifications.get_notification(notification.id, user.id)

      assert result.id == notification.id
      assert result.user_id == user.id
    end

    test "returns nil for non-existent notification" do
      user = user_fixture()

      result = Notifications.get_notification(Ecto.UUID.generate(), user.id)

      assert is_nil(result)
    end

    test "returns nil when notification belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification = notification_fixture(user1)

      result = Notifications.get_notification(notification.id, user2.id)

      assert is_nil(result)
    end
  end

  describe "create_workspace_invitation_notification/1" do
    test "creates a workspace invitation notification" do
      user = user_fixture()
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        user_id: user.id,
        workspace_id: workspace.id,
        workspace_name: workspace.name,
        invited_by_name: owner.email,
        role: "member"
      }

      assert {:ok, notification} = Notifications.create_workspace_invitation_notification(params)

      assert notification.user_id == user.id
      assert notification.type == "workspace_invitation"
      assert notification.read == false
      assert notification.data.workspace_id == workspace.id
    end
  end

  describe "list_unread_notifications/1" do
    test "returns only unread notifications" do
      user = user_fixture()
      _read_notification = notification_fixture(user, %{read: true})
      unread_notification1 = notification_fixture(user, %{read: false})
      unread_notification2 = notification_fixture(user, %{read: false})

      result = Notifications.list_unread_notifications(user.id)

      assert length(result) == 2
      notification_ids = Enum.map(result, & &1.id)
      assert unread_notification1.id in notification_ids
      assert unread_notification2.id in notification_ids
    end

    test "returns empty list when no unread notifications" do
      user = user_fixture()
      _read_notification = notification_fixture(user, %{read: true})

      result = Notifications.list_unread_notifications(user.id)

      assert result == []
    end

    test "returns empty list for user with no notifications" do
      user = user_fixture()

      result = Notifications.list_unread_notifications(user.id)

      assert result == []
    end
  end

  describe "list_notifications/2" do
    test "returns all notifications for a user" do
      user = user_fixture()
      notification1 = notification_fixture(user, %{read: true})
      notification2 = notification_fixture(user, %{read: false})

      result = Notifications.list_notifications(user.id)

      assert length(result) == 2
      notification_ids = Enum.map(result, & &1.id)
      assert notification1.id in notification_ids
      assert notification2.id in notification_ids
    end

    test "returns notifications ordered by most recent" do
      user = user_fixture()

      notification1 =
        notification_fixture(user, %{inserted_at: ~N[2024-01-01 12:00:00]})

      notification2 =
        notification_fixture(user, %{inserted_at: ~N[2024-01-02 12:00:00]})

      result = Notifications.list_notifications(user.id)

      assert length(result) == 2
      # Most recent first
      assert Enum.at(result, 0).id == notification2.id
      assert Enum.at(result, 1).id == notification1.id
    end

    test "accepts options parameter" do
      user = user_fixture()
      notification_fixture(user)

      result = Notifications.list_notifications(user.id, [])

      assert is_list(result)
    end
  end

  describe "mark_as_read/2" do
    test "marks an unread notification as read" do
      user = user_fixture()
      notification = notification_fixture(user, %{read: false})

      assert {:ok, updated_notification} = Notifications.mark_as_read(notification.id, user.id)

      assert updated_notification.read == true
      assert not is_nil(updated_notification.read_at)
    end

    test "returns error for non-existent notification" do
      user = user_fixture()

      assert {:error, _} = Notifications.mark_as_read(Ecto.UUID.generate(), user.id)
    end

    test "returns error when notification belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification = notification_fixture(user1)

      assert {:error, _} = Notifications.mark_as_read(notification.id, user2.id)
    end
  end

  describe "mark_all_as_read/1" do
    test "marks all unread notifications as read" do
      user = user_fixture()
      notification1 = notification_fixture(user, %{read: false})
      notification2 = notification_fixture(user, %{read: false})
      _notification3 = notification_fixture(user, %{read: true})

      assert {:ok, count} = Notifications.mark_all_as_read(user.id)

      assert count == 2

      # Verify notifications are now read
      updated1 = Notifications.get_notification(notification1.id, user.id)
      updated2 = Notifications.get_notification(notification2.id, user.id)

      assert updated1.read == true
      assert updated2.read == true
    end

    test "returns 0 when no unread notifications" do
      user = user_fixture()
      _notification = notification_fixture(user, %{read: true})

      assert {:ok, count} = Notifications.mark_all_as_read(user.id)

      assert count == 0
    end

    test "returns 0 for user with no notifications" do
      user = user_fixture()

      assert {:ok, count} = Notifications.mark_all_as_read(user.id)

      assert count == 0
    end
  end

  describe "unread_count/1" do
    test "returns count of unread notifications" do
      user = user_fixture()
      notification_fixture(user, %{read: false})
      notification_fixture(user, %{read: false})
      notification_fixture(user, %{read: true})

      count = Notifications.unread_count(user.id)

      assert count == 2
    end

    test "returns 0 when no unread notifications" do
      user = user_fixture()
      notification_fixture(user, %{read: true})

      count = Notifications.unread_count(user.id)

      assert count == 0
    end

    test "returns 0 for user with no notifications" do
      user = user_fixture()

      count = Notifications.unread_count(user.id)

      assert count == 0
    end
  end
end
