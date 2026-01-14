defmodule Jarga.Notifications.Application.UseCases.ListUnreadNotificationsTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Application.UseCases.ListUnreadNotifications
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  import Jarga.AccountsFixtures
  import Jarga.NotificationsFixtures

  describe "execute/1" do
    test "returns empty list when user has no notifications" do
      user = user_fixture()

      assert ListUnreadNotifications.execute(user.id) == []
    end

    test "returns only unread notifications" do
      user = user_fixture()

      unread1 = notification_fixture(user)
      unread2 = notification_fixture(user)
      read = notification_fixture(user)
      NotificationRepository.mark_as_read(read)

      notifications = ListUnreadNotifications.execute(user.id)

      assert length(notifications) == 2
      notification_ids = Enum.map(notifications, & &1.id)
      assert unread1.id in notification_ids
      assert unread2.id in notification_ids
      refute read.id in notification_ids
    end

    test "returns empty list when all notifications are read" do
      user = user_fixture()

      notification1 = notification_fixture(user)
      notification2 = notification_fixture(user)

      NotificationRepository.mark_as_read(notification1)
      NotificationRepository.mark_as_read(notification2)

      assert ListUnreadNotifications.execute(user.id) == []
    end

    test "only returns notifications for the specified user" do
      user1 = user_fixture()
      user2 = user_fixture()

      notification_fixture(user1)
      notification_fixture(user1)
      notification_fixture(user2)

      assert length(ListUnreadNotifications.execute(user1.id)) == 2
      assert length(ListUnreadNotifications.execute(user2.id)) == 1
    end

    test "returns notifications ordered by most recent" do
      user = user_fixture()

      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)

      notifications = ListUnreadNotifications.execute(user.id)

      # Verify ordered by most recent (inserted_at descending)
      timestamps = Enum.map(notifications, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end
  end
end
