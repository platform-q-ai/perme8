defmodule Jarga.Notifications.Domain.Events.NotificationActionTakenTest do
  use ExUnit.Case, async: true

  alias Jarga.Notifications.Domain.Events.NotificationActionTaken

  @valid_attrs %{
    aggregate_id: "notif-123",
    actor_id: "user-123",
    notification_id: "notif-123",
    user_id: "user-123",
    action: "accepted"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert NotificationActionTaken.event_type() == "notifications.notification_action_taken"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert NotificationActionTaken.aggregate_type() == "notification"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = NotificationActionTaken.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "notifications.notification_action_taken"
      assert event.aggregate_type == "notification"
      assert event.notification_id == "notif-123"
      assert event.user_id == "user-123"
      assert event.action == "accepted"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        NotificationActionTaken.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
