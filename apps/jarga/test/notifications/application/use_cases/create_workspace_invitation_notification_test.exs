defmodule Jarga.Notifications.Application.UseCases.CreateWorkspaceInvitationNotificationTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notifications.Application.UseCases.CreateWorkspaceInvitationNotification
  import Jarga.AccountsFixtures

  describe "execute/2" do
    test "creates workspace invitation notification with valid params" do
      user = user_fixture()
      workspace_id = Ecto.UUID.generate()

      params = %{
        user_id: user.id,
        workspace_id: workspace_id,
        workspace_name: "Acme Corp",
        invited_by_name: "John Doe",
        role: "member"
      }

      assert {:ok, notification} = CreateWorkspaceInvitationNotification.execute(params)

      assert notification.user_id == user.id
      assert notification.type == "workspace_invitation"
      assert notification.title == "Workspace Invitation: Acme Corp"
      assert notification.body == "John Doe has invited you to join Acme Corp as a member."
      assert notification.read == false
      assert is_nil(notification.read_at)
      assert is_nil(notification.action_taken_at)

      # Verify data field (Ecto stores map keys as strings)
      data = notification.data
      assert is_map(data)
      # Data can have either atom or string keys depending on how it's loaded
      assert (data["workspace_id"] || data[:workspace_id]) == workspace_id
      assert (data["workspace_name"] || data[:workspace_name]) == "Acme Corp"
      assert (data["invited_by_name"] || data[:invited_by_name]) == "John Doe"
      assert (data["role"] || data[:role]) == "member"
    end

    test "creates notification for admin role" do
      user = user_fixture()

      params = %{
        user_id: user.id,
        workspace_id: Ecto.UUID.generate(),
        workspace_name: "Tech Startup",
        invited_by_name: "Jane Smith",
        role: "admin"
      }

      assert {:ok, notification} = CreateWorkspaceInvitationNotification.execute(params)

      assert notification.title == "Workspace Invitation: Tech Startup"
      assert notification.body == "Jane Smith has invited you to join Tech Startup as a admin."
      data = notification.data
      assert (data["role"] || data[:role]) == "admin"
    end

    test "returns error when user_id is missing" do
      params = %{
        workspace_id: Ecto.UUID.generate(),
        workspace_name: "Acme Corp",
        invited_by_name: "John Doe",
        role: "member"
      }

      assert {:error, changeset} = CreateWorkspaceInvitationNotification.execute(params)
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "returns error when user doesn't exist" do
      non_existent_user_id = Ecto.UUID.generate()

      params = %{
        user_id: non_existent_user_id,
        workspace_id: Ecto.UUID.generate(),
        workspace_name: "Acme Corp",
        invited_by_name: "John Doe",
        role: "member"
      }

      assert {:error, changeset} = CreateWorkspaceInvitationNotification.execute(params)
      assert "does not exist" in errors_on(changeset).user_id
    end

    test "accepts params with atom keys" do
      user = user_fixture()

      params = %{
        user_id: user.id,
        workspace_id: Ecto.UUID.generate(),
        workspace_name: "Atom Keys Corp",
        invited_by_name: "John Doe",
        role: "member"
      }

      assert {:ok, notification} = CreateWorkspaceInvitationNotification.execute(params)
      assert notification.title == "Workspace Invitation: Atom Keys Corp"
    end

    test "accepts params with string keys" do
      user = user_fixture()

      params = %{
        "user_id" => user.id,
        "workspace_id" => Ecto.UUID.generate(),
        "workspace_name" => "String Keys Corp",
        "invited_by_name" => "John Doe",
        "role" => "member"
      }

      assert {:ok, notification} = CreateWorkspaceInvitationNotification.execute(params)
      assert notification.title == "Workspace Invitation: String Keys Corp"
    end

    test "creates notification with custom notifier option" do
      user = user_fixture()

      # Create a mock notifier module
      defmodule TestNotifier do
        def broadcast_new_notification(_user_id, _notification), do: :ok
      end

      params = %{
        user_id: user.id,
        workspace_id: Ecto.UUID.generate(),
        workspace_name: "Test Workspace",
        invited_by_name: "Test User",
        role: "member"
      }

      assert {:ok, notification} =
               CreateWorkspaceInvitationNotification.execute(params, notifier: TestNotifier)

      assert notification.type == "workspace_invitation"
    end
  end
end
