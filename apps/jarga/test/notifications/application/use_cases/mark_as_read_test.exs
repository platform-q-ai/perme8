defmodule Jarga.Notifications.Application.UseCases.MarkAsReadTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Application.UseCases.MarkAsRead
  alias Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  import Jarga.AccountsFixtures
  import Jarga.NotificationsFixtures

  describe "execute/2" do
    test "marks notification as read and returns {:ok, notification}" do
      user = user_fixture()
      notification = notification_fixture(user)

      assert notification.read == false
      assert is_nil(notification.read_at)

      assert {:ok, updated} = MarkAsRead.execute(notification.id, user.id)

      assert updated.id == notification.id
      assert updated.read == true
      assert %DateTime{} = updated.read_at
    end

    test "returns {:error, :not_found} when notification doesn't exist" do
      user = user_fixture()
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = MarkAsRead.execute(non_existent_id, user.id)
    end

    test "returns {:error, :not_found} when notification belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification = notification_fixture(user1)

      assert {:error, :not_found} = MarkAsRead.execute(notification.id, user2.id)
    end

    test "successfully marks already read notification as read again" do
      user = user_fixture()
      notification = notification_fixture(user)

      # Mark as read first time
      {:ok, first_update} = MarkAsRead.execute(notification.id, user.id)
      assert first_update.read == true
      first_read_at = first_update.read_at

      # Mark as read second time
      {:ok, second_update} = MarkAsRead.execute(notification.id, user.id)
      assert second_update.read == true
      assert %DateTime{} = second_update.read_at
      # read_at should be updated
      assert DateTime.compare(second_update.read_at, first_read_at) in [:gt, :eq]
    end

    test "only affects the specified notification" do
      user = user_fixture()
      notification1 = notification_fixture(user)
      notification2 = notification_fixture(user)

      {:ok, _updated} = MarkAsRead.execute(notification1.id, user.id)

      # notification1 should be read
      updated1 = NotificationRepository.get(notification1.id)
      assert updated1.read == true

      # notification2 should still be unread
      updated2 = NotificationRepository.get(notification2.id)
      assert updated2.read == false
    end
  end
end
