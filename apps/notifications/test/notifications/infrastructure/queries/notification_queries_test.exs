defmodule Notifications.Infrastructure.Queries.NotificationQueriesTest do
  use Notifications.DataCase, async: true

  alias Notifications.Infrastructure.Queries.NotificationQueries
  alias Notifications.Infrastructure.Schemas.NotificationSchema

  import Notifications.Test.Fixtures.NotificationsFixtures
  import Notifications.Test.Fixtures.AccountsFixtures

  describe "base/0" do
    test "returns base query for NotificationSchema" do
      query = NotificationQueries.base()
      assert %Ecto.Query{} = query
    end
  end

  describe "by_user/2" do
    test "filters notifications by user_id" do
      user = user_fixture()
      other_user = user_fixture()

      _notification1 = notification_fixture(user.id)
      _notification2 = notification_fixture(user.id)
      _notification3 = notification_fixture(other_user.id)

      results =
        NotificationQueries.base()
        |> NotificationQueries.by_user(user.id)
        |> Repo.all()

      assert length(results) == 2
      assert Enum.all?(results, &(&1.user_id == user.id))
    end
  end

  describe "unread/1" do
    test "filters to only unread notifications" do
      user = user_fixture()

      unread = notification_fixture(user.id)
      read = notification_fixture(user.id)

      # Mark one as read directly
      read
      |> NotificationSchema.mark_read_changeset()
      |> Repo.update!()

      results =
        NotificationQueries.base()
        |> NotificationQueries.by_user(user.id)
        |> NotificationQueries.unread()
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == unread.id
    end
  end

  describe "ordered_by_recent/1" do
    test "orders notifications by inserted_at descending" do
      user = user_fixture()

      _n1 = notification_fixture(user.id)
      _n2 = notification_fixture(user.id)
      _n3 = notification_fixture(user.id)

      results =
        NotificationQueries.base()
        |> NotificationQueries.by_user(user.id)
        |> NotificationQueries.ordered_by_recent()
        |> Repo.all()

      timestamps = Enum.map(results, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end
  end

  describe "limited/2" do
    test "limits the number of results" do
      user = user_fixture()

      _n1 = notification_fixture(user.id)
      _n2 = notification_fixture(user.id)
      _n3 = notification_fixture(user.id)

      results =
        NotificationQueries.base()
        |> NotificationQueries.by_user(user.id)
        |> NotificationQueries.limited(2)
        |> Repo.all()

      assert length(results) == 2
    end
  end
end
