defmodule Notifications.Application.UseCases.ListUnreadNotificationsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.ListUnreadNotifications
  alias Notifications.Mocks.NotificationRepositoryMock

  setup :verify_on_exit!

  describe "execute/2" do
    test "delegates to repository list_unread_by_user" do
      user_id = Ecto.UUID.generate()

      notifications = [
        %{id: Ecto.UUID.generate(), user_id: user_id, read: false},
        %{id: Ecto.UUID.generate(), user_id: user_id, read: false}
      ]

      NotificationRepositoryMock
      |> expect(:list_unread_by_user, fn ^user_id, _opts -> notifications end)

      assert ^notifications =
               ListUnreadNotifications.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns empty list when user has no unread notifications" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:list_unread_by_user, fn ^user_id, _opts -> [] end)

      assert [] ==
               ListUnreadNotifications.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end
  end
end
