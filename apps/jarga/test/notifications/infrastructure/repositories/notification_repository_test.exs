defmodule Jarga.Notifications.Infrastructure.NotificationRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  import Jarga.AccountsFixtures
  import Jarga.NotificationsFixtures

  describe "create/1" do
    test "creates a notification with valid attributes" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        type: "workspace_invitation",
        title: "Test Notification",
        body: "Test body",
        data: %{
          workspace_id: Ecto.UUID.generate(),
          workspace_name: "Test Workspace",
          invited_by_name: "Test User",
          role: "member"
        }
      }

      assert {:ok, notification} = NotificationRepository.create(attrs)
      assert notification.user_id == user.id
      assert notification.type == "workspace_invitation"
      assert notification.title == "Test Notification"
      assert notification.body == "Test body"
      assert notification.read == false
      assert is_nil(notification.read_at)
      assert is_nil(notification.action_taken_at)
    end

    test "returns error with invalid type" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        type: "invalid_type",
        title: "Test Notification",
        body: "Test body",
        data: %{}
      }

      assert {:error, changeset} = NotificationRepository.create(attrs)
      assert "is invalid" in errors_on(changeset).type
    end

    test "returns error without required fields" do
      assert {:error, changeset} = NotificationRepository.create(%{})
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).type
      assert "can't be blank" in errors_on(changeset).title
    end
  end

  describe "get/1" do
    test "returns notification by id" do
      user = user_fixture()
      notification = notification_fixture(user)

      assert fetched = NotificationRepository.get(notification.id)
      assert fetched.id == notification.id
    end

    test "returns nil when notification doesn't exist" do
      non_existent_id = Ecto.UUID.generate()

      assert NotificationRepository.get(non_existent_id) == nil
    end
  end

  describe "get_by_user/2" do
    test "returns notification when it belongs to user" do
      user = user_fixture()
      notification = notification_fixture(user)

      assert fetched = NotificationRepository.get_by_user(notification.id, user.id)
      assert fetched.id == notification.id
    end

    test "returns nil when notification belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification = notification_fixture(user1)

      assert NotificationRepository.get_by_user(notification.id, user2.id) == nil
    end

    test "returns nil when notification doesn't exist" do
      user = user_fixture()
      non_existent_id = Ecto.UUID.generate()

      assert NotificationRepository.get_by_user(non_existent_id, user.id) == nil
    end
  end

  describe "list_by_user/2" do
    test "returns all notifications for user ordered by most recent" do
      user = user_fixture()
      notification1 = notification_fixture(user)
      notification2 = notification_fixture(user)
      notification3 = notification_fixture(user)

      notifications = NotificationRepository.list_by_user(user.id)

      assert length(notifications) == 3
      # Verify all notifications are present
      notification_ids = Enum.map(notifications, & &1.id)
      assert notification1.id in notification_ids
      assert notification2.id in notification_ids
      assert notification3.id in notification_ids

      # Verify ordered by most recent (inserted_at descending)
      timestamps = Enum.map(notifications, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "returns empty list when user has no notifications" do
      user = user_fixture()

      assert NotificationRepository.list_by_user(user.id) == []
    end

    test "does not return notifications for other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification_fixture(user1)
      notification_fixture(user1)

      assert NotificationRepository.list_by_user(user2.id) == []
    end

    test "respects limit option" do
      user = user_fixture()
      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)

      notifications = NotificationRepository.list_by_user(user.id, limit: 2)

      assert length(notifications) == 2
    end
  end

  describe "list_unread_by_user/1" do
    test "returns only unread notifications" do
      user = user_fixture()
      unread1 = notification_fixture(user)
      unread2 = notification_fixture(user)
      read_notification = notification_fixture(user)
      NotificationRepository.mark_as_read(read_notification)

      unread = NotificationRepository.list_unread_by_user(user.id)

      assert length(unread) == 2
      assert Enum.any?(unread, &(&1.id == unread1.id))
      assert Enum.any?(unread, &(&1.id == unread2.id))
      refute Enum.any?(unread, &(&1.id == read_notification.id))
    end

    test "returns empty list when all notifications are read" do
      user = user_fixture()
      notification = notification_fixture(user)
      NotificationRepository.mark_as_read(notification)

      assert NotificationRepository.list_unread_by_user(user.id) == []
    end

    test "returns empty list when user has no notifications" do
      user = user_fixture()

      assert NotificationRepository.list_unread_by_user(user.id) == []
    end
  end

  describe "count_unread_by_user/1" do
    test "returns count of unread notifications" do
      user = user_fixture()
      notification_fixture(user)
      notification_fixture(user)
      read_notification = notification_fixture(user)
      NotificationRepository.mark_as_read(read_notification)

      assert NotificationRepository.count_unread_by_user(user.id) == 2
    end

    test "returns 0 when all notifications are read" do
      user = user_fixture()
      notification = notification_fixture(user)
      NotificationRepository.mark_as_read(notification)

      assert NotificationRepository.count_unread_by_user(user.id) == 0
    end

    test "returns 0 when user has no notifications" do
      user = user_fixture()

      assert NotificationRepository.count_unread_by_user(user.id) == 0
    end
  end

  describe "mark_as_read/1" do
    test "marks notification as read and sets read_at timestamp" do
      user = user_fixture()
      notification = notification_fixture(user)

      assert notification.read == false
      assert is_nil(notification.read_at)

      assert {:ok, updated} = NotificationRepository.mark_as_read(notification)
      assert updated.read == true
      assert %DateTime{} = updated.read_at
    end

    test "can mark already read notification as read again" do
      user = user_fixture()
      notification = notification_fixture(user)

      {:ok, first_update} = NotificationRepository.mark_as_read(notification)
      assert first_update.read == true

      {:ok, second_update} = NotificationRepository.mark_as_read(first_update)
      assert second_update.read == true
      assert %DateTime{} = second_update.read_at
    end
  end

  describe "mark_all_as_read/1" do
    test "marks all unread notifications as read for user" do
      user = user_fixture()
      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)

      assert NotificationRepository.count_unread_by_user(user.id) == 3

      assert {:ok, 3} = NotificationRepository.mark_all_as_read(user.id)
      assert NotificationRepository.count_unread_by_user(user.id) == 0
    end

    test "returns 0 when no unread notifications" do
      user = user_fixture()
      notification = notification_fixture(user)
      NotificationRepository.mark_as_read(notification)

      assert {:ok, 0} = NotificationRepository.mark_all_as_read(user.id)
    end

    test "only marks notifications for specified user" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification_fixture(user1)
      notification_fixture(user2)

      {:ok, count} = NotificationRepository.mark_all_as_read(user1.id)

      assert count == 1
      assert NotificationRepository.count_unread_by_user(user2.id) == 1
    end
  end

  describe "mark_action_taken/1" do
    test "sets action_taken_at timestamp" do
      user = user_fixture()
      notification = notification_fixture(user)

      assert is_nil(notification.action_taken_at)

      assert {:ok, updated} = NotificationRepository.mark_action_taken(notification)
      assert %DateTime{} = updated.action_taken_at
    end
  end

  describe "delete/1" do
    test "deletes a notification" do
      user = user_fixture()
      notification = notification_fixture(user)

      assert {:ok, _} = NotificationRepository.delete(notification)
      assert NotificationRepository.get(notification.id) == nil
    end
  end
end
