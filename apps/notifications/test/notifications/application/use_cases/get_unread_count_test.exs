defmodule Notifications.Application.UseCases.GetUnreadCountTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.GetUnreadCount
  alias Notifications.Mocks.NotificationRepositoryMock

  setup :verify_on_exit!

  describe "execute/2" do
    test "returns integer count from repository" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:count_unread_by_user, fn ^user_id -> 7 end)

      assert 7 ==
               GetUnreadCount.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns 0 when user has no unread notifications" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:count_unread_by_user, fn ^user_id -> 0 end)

      assert 0 ==
               GetUnreadCount.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end
  end
end
