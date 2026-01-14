defmodule Jarga.Notifications.Application.UseCases.GetUnreadCountTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Application.UseCases.GetUnreadCount
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  import Jarga.AccountsFixtures
  import Jarga.NotificationsFixtures

  describe "execute/1" do
    test "returns 0 when user has no notifications" do
      user = user_fixture()

      assert GetUnreadCount.execute(user.id) == 0
    end

    test "returns count of unread notifications" do
      user = user_fixture()

      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)

      assert GetUnreadCount.execute(user.id) == 3
    end

    test "does not count read notifications" do
      user = user_fixture()

      notification1 = notification_fixture(user)
      notification_fixture(user)
      notification3 = notification_fixture(user)

      # Mark two as read
      NotificationRepository.mark_as_read(notification1)
      NotificationRepository.mark_as_read(notification3)

      assert GetUnreadCount.execute(user.id) == 1
    end

    test "only counts notifications for the specified user" do
      user1 = user_fixture()
      user2 = user_fixture()

      notification_fixture(user1)
      notification_fixture(user1)
      notification_fixture(user2)
      notification_fixture(user2)
      notification_fixture(user2)

      assert GetUnreadCount.execute(user1.id) == 2
      assert GetUnreadCount.execute(user2.id) == 3
    end
  end
end
