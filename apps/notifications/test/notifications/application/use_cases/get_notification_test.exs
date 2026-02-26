defmodule Notifications.Application.UseCases.GetNotificationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.GetNotification
  alias Notifications.Mocks.NotificationRepositoryMock

  setup :verify_on_exit!

  describe "execute/3" do
    test "returns notification when it exists for user" do
      notification_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      notification = %{
        id: notification_id,
        user_id: user_id,
        type: "workspace_invitation",
        read: false
      }

      NotificationRepositoryMock
      |> expect(:get_by_user, fn ^notification_id, ^user_id -> notification end)

      assert ^notification =
               GetNotification.execute(notification_id, user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns nil when notification doesn't exist" do
      notification_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:get_by_user, fn ^notification_id, ^user_id -> nil end)

      assert is_nil(
               GetNotification.execute(notification_id, user_id,
                 notification_repository: NotificationRepositoryMock
               )
             )
    end

    test "returns nil when notification belongs to different user" do
      notification_id = Ecto.UUID.generate()
      wrong_user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:get_by_user, fn ^notification_id, ^wrong_user_id -> nil end)

      assert is_nil(
               GetNotification.execute(notification_id, wrong_user_id,
                 notification_repository: NotificationRepositoryMock
               )
             )
    end
  end
end
