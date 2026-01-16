defmodule Jarga.Notifications.Application.UseCases.ListNotificationsTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Application.UseCases.ListNotifications
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  import Jarga.AccountsFixtures
  import Jarga.NotificationsFixtures

  describe "execute/2" do
    test "returns empty list when user has no notifications" do
      user = user_fixture()

      assert ListNotifications.execute(user.id) == []
    end

    test "returns all notifications for user ordered by most recent" do
      user = user_fixture()

      notification1 = notification_fixture(user)
      notification2 = notification_fixture(user)
      notification3 = notification_fixture(user)

      notifications = ListNotifications.execute(user.id)

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

    test "includes both read and unread notifications" do
      user = user_fixture()

      unread = notification_fixture(user)
      read = notification_fixture(user)
      NotificationRepository.mark_as_read(read)

      notifications = ListNotifications.execute(user.id)

      assert length(notifications) == 2
      notification_ids = Enum.map(notifications, & &1.id)
      assert unread.id in notification_ids
      assert read.id in notification_ids
    end

    test "only returns notifications for the specified user" do
      user1 = user_fixture()
      user2 = user_fixture()

      notification_fixture(user1)
      notification_fixture(user2)

      assert length(ListNotifications.execute(user1.id)) == 1
      assert length(ListNotifications.execute(user2.id)) == 1
    end

    test "respects limit option" do
      user = user_fixture()

      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)

      notifications = ListNotifications.execute(user.id, limit: 3)

      assert length(notifications) == 3
    end

    test "returns all notifications when no limit is specified" do
      user = user_fixture()

      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)
      notification_fixture(user)

      notifications = ListNotifications.execute(user.id)

      assert length(notifications) == 5
    end
  end
end
