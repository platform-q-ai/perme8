defmodule Jarga.Notifications.Domain.Events.NotificationCreatedTest do
  use ExUnit.Case, async: true

  alias Jarga.Notifications.Domain.Events.NotificationCreated

  @valid_attrs %{
    aggregate_id: "notif-123",
    actor_id: "user-123",
    notification_id: "notif-123",
    user_id: "user-123",
    type: "workspace_invitation"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert NotificationCreated.event_type() == "notifications.notification_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert NotificationCreated.aggregate_type() == "notification"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = NotificationCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "notifications.notification_created"
      assert event.aggregate_type == "notification"
      assert event.notification_id == "notif-123"
      assert event.user_id == "user-123"
      assert event.type == "workspace_invitation"
    end

    test "workspace_id is optional" do
      event = NotificationCreated.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        NotificationCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
