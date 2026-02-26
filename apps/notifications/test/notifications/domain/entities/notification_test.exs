defmodule Notifications.Domain.Entities.NotificationTest do
  use ExUnit.Case, async: true

  alias Notifications.Domain.Entities.Notification

  describe "new/1" do
    test "creates a notification struct from an attrs map" do
      attrs = %{
        id: "notif-123",
        user_id: "user-456",
        type: "workspace_invitation",
        title: "You have been invited",
        body: "Join workspace Acme",
        data: %{"workspace_id" => "ws-789"},
        read: false,
        read_at: nil,
        action_taken_at: nil,
        inserted_at: ~U[2026-01-01 12:00:00Z],
        updated_at: ~U[2026-01-01 12:00:00Z]
      }

      notification = Notification.new(attrs)

      assert notification.id == "notif-123"
      assert notification.user_id == "user-456"
      assert notification.type == "workspace_invitation"
      assert notification.title == "You have been invited"
      assert notification.body == "Join workspace Acme"
      assert notification.data == %{"workspace_id" => "ws-789"}
      assert notification.read == false
      assert notification.read_at == nil
      assert notification.action_taken_at == nil
      assert notification.inserted_at == ~U[2026-01-01 12:00:00Z]
      assert notification.updated_at == ~U[2026-01-01 12:00:00Z]
    end

    test "provides default values for optional fields" do
      attrs = %{
        id: "notif-123",
        user_id: "user-456",
        type: "workspace_invitation",
        title: "Invited"
      }

      notification = Notification.new(attrs)

      assert notification.data == %{}
      assert notification.read == false
      assert notification.read_at == nil
      assert notification.body == nil
      assert notification.action_taken_at == nil
      assert notification.inserted_at == nil
      assert notification.updated_at == nil
    end
  end

  describe "from_schema/1" do
    test "converts a schema-like map to a notification entity" do
      schema = %{
        id: "notif-abc",
        user_id: "user-xyz",
        type: "workspace_invitation",
        title: "Invitation",
        body: "You were invited",
        data: %{"key" => "value"},
        read: true,
        read_at: ~U[2026-01-02 10:00:00Z],
        action_taken_at: ~U[2026-01-02 10:30:00Z],
        inserted_at: ~U[2026-01-01 08:00:00Z],
        updated_at: ~U[2026-01-02 10:00:00Z]
      }

      notification = Notification.from_schema(schema)

      assert %Notification{} = notification
      assert notification.id == "notif-abc"
      assert notification.user_id == "user-xyz"
      assert notification.type == "workspace_invitation"
      assert notification.title == "Invitation"
      assert notification.body == "You were invited"
      assert notification.data == %{"key" => "value"}
      assert notification.read == true
      assert notification.read_at == ~U[2026-01-02 10:00:00Z]
      assert notification.action_taken_at == ~U[2026-01-02 10:30:00Z]
      assert notification.inserted_at == ~U[2026-01-01 08:00:00Z]
      assert notification.updated_at == ~U[2026-01-02 10:00:00Z]
    end

    test "converts a struct to a notification entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "notif-abc",
        user_id: "user-xyz",
        type: "workspace_invitation",
        title: "Invitation",
        body: nil,
        data: %{},
        read: false,
        read_at: nil,
        action_taken_at: nil,
        inserted_at: ~U[2026-01-01 08:00:00Z],
        updated_at: ~U[2026-01-01 08:00:00Z]
      }

      notification = Notification.from_schema(schema)

      assert %Notification{} = notification
      assert notification.id == "notif-abc"
      assert notification.type == "workspace_invitation"
    end
  end

  describe "struct fields" do
    test "has all expected fields" do
      notification = %Notification{}

      assert Map.has_key?(notification, :id)
      assert Map.has_key?(notification, :user_id)
      assert Map.has_key?(notification, :type)
      assert Map.has_key?(notification, :title)
      assert Map.has_key?(notification, :body)
      assert Map.has_key?(notification, :data)
      assert Map.has_key?(notification, :read)
      assert Map.has_key?(notification, :read_at)
      assert Map.has_key?(notification, :action_taken_at)
      assert Map.has_key?(notification, :inserted_at)
      assert Map.has_key?(notification, :updated_at)
    end
  end
end
