defmodule Notifications.Application.UseCases.MarkAllAsReadTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.MarkAllAsRead
  alias Notifications.Mocks.NotificationRepositoryMock

  setup :verify_on_exit!

  describe "execute/2" do
    test "delegates to repository mark_all_as_read and returns {:ok, count}" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:mark_all_as_read, fn ^user_id -> {:ok, 5} end)

      assert {:ok, 5} =
               MarkAllAsRead.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns {:ok, 0} when user has no unread notifications" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:mark_all_as_read, fn ^user_id -> {:ok, 0} end)

      assert {:ok, 0} =
               MarkAllAsRead.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end
  end
end
