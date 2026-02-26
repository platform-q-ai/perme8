defmodule Notifications.Application.UseCases.CreateNotificationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Notifications.Application.UseCases.CreateNotification
  alias Notifications.Domain.Events.NotificationCreated
  alias Notifications.Mocks.NotificationRepositoryMock
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    bus_name = :"test_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: bus_name)
    %{bus_name: bus_name}
  end

  describe "execute/2" do
    test "creates notification via repository and emits NotificationCreated event", %{
      bus_name: bus_name
    } do
      notification_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      returned_notification = %{
        id: notification_id,
        user_id: user_id,
        type: "workspace_invitation",
        title: "Workspace Invitation: Acme Corp",
        body: "John invited you to join Acme Corp as a member.",
        data: %{workspace_id: Ecto.UUID.generate()},
        read: false,
        read_at: nil
      }

      NotificationRepositoryMock
      |> expect(:create, fn attrs ->
        assert attrs.user_id == user_id
        assert attrs.type == "workspace_invitation"
        assert attrs.title == "Workspace Invitation: Acme Corp"
        assert attrs.body == "John invited you to join Acme Corp as a member."
        {:ok, returned_notification}
      end)

      params = %{
        user_id: user_id,
        type: "workspace_invitation",
        title: "Workspace Invitation: Acme Corp",
        body: "John invited you to join Acme Corp as a member.",
        data: %{workspace_id: Ecto.UUID.generate()}
      }

      assert {:ok, ^returned_notification} =
               CreateNotification.execute(params,
                 notification_repository: NotificationRepositoryMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )

      events = TestEventBus.get_events(name: bus_name)
      assert [%NotificationCreated{} = event] = events
      assert event.notification_id == notification_id
      assert event.user_id == user_id
      assert event.type == "workspace_invitation"
      assert event.aggregate_id == notification_id
      assert event.actor_id == user_id
      assert event.target_user_id == user_id
    end

    test "returns {:error, changeset} on validation failure and does not emit event", %{
      bus_name: bus_name
    } do
      changeset = %Ecto.Changeset{valid?: false, errors: [user_id: {"can't be blank", []}]}

      NotificationRepositoryMock
      |> expect(:create, fn _attrs ->
        {:error, changeset}
      end)

      params = %{
        type: "workspace_invitation",
        title: "Some Title",
        body: "Some body"
      }

      assert {:error, ^changeset} =
               CreateNotification.execute(params,
                 notification_repository: NotificationRepositoryMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )

      assert [] = TestEventBus.get_events(name: bus_name)
    end

    test "auto-builds title and body for workspace_invitation type when not provided", %{
      bus_name: bus_name
    } do
      user_id = Ecto.UUID.generate()
      notification_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:create, fn attrs ->
        assert attrs.title == "Workspace Invitation: Acme Corp"
        assert attrs.body == "Jane has invited you to join Acme Corp as a admin."
        {:ok, %{id: notification_id, user_id: user_id, type: "workspace_invitation"}}
      end)

      params = %{
        user_id: user_id,
        type: "workspace_invitation",
        data: %{
          workspace_name: "Acme Corp",
          invited_by_name: "Jane",
          role: "admin"
        }
      }

      assert {:ok, _notification} =
               CreateNotification.execute(params,
                 notification_repository: NotificationRepositoryMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )
    end

    test "uses provided title and body even for workspace_invitation type", %{
      bus_name: bus_name
    } do
      user_id = Ecto.UUID.generate()
      notification_id = Ecto.UUID.generate()

      NotificationRepositoryMock
      |> expect(:create, fn attrs ->
        assert attrs.title == "Custom Title"
        assert attrs.body == "Custom Body"
        {:ok, %{id: notification_id, user_id: user_id, type: "workspace_invitation"}}
      end)

      params = %{
        user_id: user_id,
        type: "workspace_invitation",
        title: "Custom Title",
        body: "Custom Body",
        data: %{
          workspace_name: "Acme Corp",
          invited_by_name: "Jane",
          role: "admin"
        }
      }

      assert {:ok, _notification} =
               CreateNotification.execute(params,
                 notification_repository: NotificationRepositoryMock,
                 event_bus: TestEventBus,
                 event_bus_opts: [name: bus_name]
               )
    end
  end
end
