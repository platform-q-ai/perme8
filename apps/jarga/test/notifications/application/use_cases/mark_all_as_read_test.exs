defmodule Jarga.Notifications.Application.UseCases.MarkAllAsReadTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Application.UseCases.MarkAllAsRead
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  import Jarga.AccountsFixtures
  import Jarga.NotificationsFixtures

  describe "execute/1" do
    test "returns {:ok, 0} when user has no notifications" do
      user = user_fixture()

      assert {:ok, 0} = MarkAllAsRead.execute(user.id)
    end

    test "marks all unread notifications as read and returns count" do
      user = user_fixture()

      notification1 = notification_fixture(user)
      notification2 = notification_fixture(user)
      notification3 = notification_fixture(user)

      # All should be unread initially
      assert notification1.read == false
      assert notification2.read == false
      assert notification3.read == false

      assert {:ok, 3} = MarkAllAsRead.execute(user.id)

      # Verify all are now read
      updated1 = NotificationRepository.get(notification1.id)
      updated2 = NotificationRepository.get(notification2.id)
      updated3 = NotificationRepository.get(notification3.id)

      assert updated1.read == true
      assert updated2.read == true
      assert updated3.read == true
    end

    test "returns {:ok, 0} when all notifications are already read" do
      user = user_fixture()

      notification = notification_fixture(user)
      NotificationRepository.mark_as_read(notification)

      assert {:ok, 0} = MarkAllAsRead.execute(user.id)
    end

    test "only marks notifications for the specified user" do
      user1 = user_fixture()
      user2 = user_fixture()

      notification1 = notification_fixture(user1)
      notification2 = notification_fixture(user2)

      assert {:ok, 1} = MarkAllAsRead.execute(user1.id)

      # user1's notification should be read
      updated1 = NotificationRepository.get(notification1.id)
      assert updated1.read == true

      # user2's notification should still be unread
      updated2 = NotificationRepository.get(notification2.id)
      assert updated2.read == false
    end

    test "sets read_at timestamp on all notifications" do
      user = user_fixture()

      notification1 = notification_fixture(user)
      notification2 = notification_fixture(user)

      assert is_nil(notification1.read_at)
      assert is_nil(notification2.read_at)

      assert {:ok, 2} = MarkAllAsRead.execute(user.id)

      updated1 = NotificationRepository.get(notification1.id)
      updated2 = NotificationRepository.get(notification2.id)

      assert %DateTime{} = updated1.read_at
      assert %DateTime{} = updated2.read_at
    end
  end
end
