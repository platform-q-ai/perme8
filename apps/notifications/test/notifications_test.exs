defmodule NotificationsTest do
  @moduledoc """
  Integration tests for the Notifications public facade.

  Tests the full stack: facade -> use cases -> repository -> database.
  """
  use Notifications.DataCase, async: true

  import Notifications.Test.Fixtures.AccountsFixtures
  import Notifications.Test.Fixtures.NotificationsFixtures

  describe "create_notification/1" do
    test "creates a notification and returns {:ok, notification}" do
      user = user_fixture()

      assert {:ok, notification} =
               Notifications.create_notification(%{
                 user_id: user.id,
                 type: "workspace_invitation",
                 title: "Workspace Invitation: Acme",
                 body: "You've been invited to Acme",
                 data: %{"workspace_id" => Ecto.UUID.generate(), "workspace_name" => "Acme"}
               })

      assert notification.user_id == user.id
      assert notification.type == "workspace_invitation"
      assert notification.title == "Workspace Invitation: Acme"
      assert notification.read == false
    end

    test "returns {:error, changeset} on validation failure" do
      assert {:error, changeset} = Notifications.create_notification(%{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "create_workspace_invitation_notification/1" do
    test "creates a workspace invitation notification with auto-built title and body" do
      user = user_fixture()
      workspace_id = Ecto.UUID.generate()

      assert {:ok, notification} =
               Notifications.create_workspace_invitation_notification(%{
                 user_id: user.id,
                 workspace_id: workspace_id,
                 workspace_name: "Acme Corp",
                 invited_by_name: "John Doe",
                 role: "member"
               })

      assert notification.type == "workspace_invitation"
      assert notification.title == "Workspace Invitation: Acme Corp"
      assert notification.body =~ "John Doe"
      assert notification.body =~ "Acme Corp"
      assert notification.body =~ "member"
      assert notification.data["workspace_id"] == workspace_id
    end
  end

  describe "get_notification/2" do
    test "returns notification for the correct user" do
      user = user_fixture()
      notification = notification_fixture(user.id)

      result = Notifications.get_notification(notification.id, user.id)
      assert result.id == notification.id
    end

    test "returns nil for wrong user" do
      user = user_fixture()
      other_user = user_fixture()
      notification = notification_fixture(user.id)

      assert Notifications.get_notification(notification.id, other_user.id) == nil
    end

    test "returns nil for non-existent notification" do
      user = user_fixture()
      assert Notifications.get_notification(Ecto.UUID.generate(), user.id) == nil
    end
  end

  describe "list_notifications/2" do
    test "returns all notifications for user" do
      user = user_fixture()
      _n1 = notification_fixture(user.id, %{title: "First"})
      _n2 = notification_fixture(user.id, %{title: "Second"})

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 2
    end

    test "respects limit option" do
      user = user_fixture()
      _n1 = notification_fixture(user.id)
      _n2 = notification_fixture(user.id)
      _n3 = notification_fixture(user.id)

      notifications = Notifications.list_notifications(user.id, limit: 2)
      assert length(notifications) == 2
    end

    test "does not return other user's notifications" do
      user = user_fixture()
      other_user = user_fixture()
      _n1 = notification_fixture(user.id)
      _n2 = notification_fixture(other_user.id)

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 1
    end
  end

  describe "list_unread_notifications/1" do
    test "returns only unread notifications" do
      user = user_fixture()
      _unread = notification_fixture(user.id, %{title: "Unread"})
      read = notification_fixture(user.id, %{title: "Read"})

      # Mark one as read
      Notifications.mark_as_read(read.id, user.id)

      unread_notifications = Notifications.list_unread_notifications(user.id)
      assert length(unread_notifications) == 1
      assert hd(unread_notifications).title == "Unread"
    end
  end

  describe "mark_as_read/2" do
    test "marks notification as read and returns {:ok, notification}" do
      user = user_fixture()
      notification = notification_fixture(user.id)

      assert {:ok, updated} = Notifications.mark_as_read(notification.id, user.id)
      assert updated.read == true
      assert updated.read_at != nil
    end

    test "returns {:error, :not_found} for wrong user" do
      user = user_fixture()
      other_user = user_fixture()
      notification = notification_fixture(user.id)

      assert {:error, :not_found} = Notifications.mark_as_read(notification.id, other_user.id)
    end

    test "returns {:error, :not_found} for non-existent notification" do
      user = user_fixture()
      assert {:error, :not_found} = Notifications.mark_as_read(Ecto.UUID.generate(), user.id)
    end
  end

  describe "mark_all_as_read/1" do
    test "marks all notifications as read and returns {:ok, count}" do
      user = user_fixture()
      _n1 = notification_fixture(user.id)
      _n2 = notification_fixture(user.id)
      _n3 = notification_fixture(user.id)

      assert {:ok, 3} = Notifications.mark_all_as_read(user.id)
      assert Notifications.unread_count(user.id) == 0
    end

    test "returns {:ok, 0} when no unread notifications" do
      user = user_fixture()
      assert {:ok, 0} = Notifications.mark_all_as_read(user.id)
    end
  end

  describe "unread_count/1" do
    test "returns integer count of unread notifications" do
      user = user_fixture()
      _n1 = notification_fixture(user.id)
      _n2 = notification_fixture(user.id)

      assert Notifications.unread_count(user.id) == 2
    end

    test "returns 0 when no notifications" do
      user = user_fixture()
      assert Notifications.unread_count(user.id) == 0
    end
  end

  describe "user scoping" do
    test "user A notifications not visible to user B" do
      user_a = user_fixture()
      user_b = user_fixture()

      _na = notification_fixture(user_a.id, %{title: "A's notification"})
      _nb = notification_fixture(user_b.id, %{title: "B's notification"})

      a_notifications = Notifications.list_notifications(user_a.id)
      b_notifications = Notifications.list_notifications(user_b.id)

      assert length(a_notifications) == 1
      assert length(b_notifications) == 1
      assert hd(a_notifications).title == "A's notification"
      assert hd(b_notifications).title == "B's notification"

      assert Notifications.unread_count(user_a.id) == 1
      assert Notifications.unread_count(user_b.id) == 1
    end
  end
end
