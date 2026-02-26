defmodule Notifications.Application.UseCases.MarkAsReadTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.MarkAsRead
  alias Notifications.Mocks.NotificationRepositoryMock

  setup :verify_on_exit!

  describe "execute/3" do
    test "marks notification as read via repository" do
      notification_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      notification = %{
        id: notification_id,
        user_id: user_id,
        read: false,
        read_at: nil
      }

      updated_notification = %{
        id: notification_id,
        user_id: user_id,
        read: true,
        read_at: DateTime.utc_now()
      }

      NotificationRepositoryMock
      |> expect(:get_by_user, fn ^notification_id, ^user_id -> notification end)
      |> expect(:mark_as_read, fn ^notification -> {:ok, updated_notification} end)

      assert {:ok, ^updated_notification} =
               MarkAsRead.execute(notification_id, user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns {:error, :not_found} when notification doesn't exist" do
      notification_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:get_by_user, fn ^notification_id, ^user_id -> nil end)

      assert {:error, :not_found} =
               MarkAsRead.execute(notification_id, user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns {:error, :not_found} when notification belongs to different user" do
      notification_id = Ecto.UUID.generate()
      wrong_user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:get_by_user, fn ^notification_id, ^wrong_user_id -> nil end)

      assert {:error, :not_found} =
               MarkAsRead.execute(notification_id, wrong_user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end
  end
end
