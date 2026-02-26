defmodule Notifications.Application.UseCases.ListNotificationsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.ListNotifications
  alias Notifications.Mocks.NotificationRepositoryMock

  setup :verify_on_exit!

  describe "execute/2" do
    test "delegates to repository list_by_user with user_id and opts" do
      user_id = Ecto.UUID.generate()

      notifications = [
        %{id: Ecto.UUID.generate(), user_id: user_id, type: "workspace_invitation"},
        %{id: Ecto.UUID.generate(), user_id: user_id, type: "workspace_invitation"}
      ]

      NotificationRepositoryMock
      |> expect(:list_by_user, fn ^user_id, opts ->
        assert opts == [limit: 10]
        notifications
      end)

      assert ^notifications =
               ListNotifications.execute(user_id,
                 limit: 10,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "returns empty list when user has no notifications" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:list_by_user, fn ^user_id, _opts -> [] end)

      assert [] ==
               ListNotifications.execute(user_id,
                 notification_repository: NotificationRepositoryMock
               )
    end

    test "passes through opts without notification_repository key" do
      user_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:list_by_user, fn ^user_id, opts ->
        # notification_repository should not leak through to the repo
        refute Keyword.has_key?(opts, :notification_repository)
        assert Keyword.get(opts, :limit) == 5
        []
      end)

      ListNotifications.execute(user_id,
        limit: 5,
        notification_repository: NotificationRepositoryMock
      )
    end
  end
end
