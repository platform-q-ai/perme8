defmodule Notifications.Domain.Policies.NotificationPolicyTest do
  use ExUnit.Case, async: true

  alias Notifications.Domain.Entities.Notification
  alias Notifications.Domain.Policies.NotificationPolicy

  describe "belongs_to_user?/2" do
    test "returns true when notification user_id matches the given user_id" do
      notification = %Notification{user_id: "user-123"}
      assert NotificationPolicy.belongs_to_user?(notification, "user-123") == true
    end

    test "returns false when notification user_id does not match" do
      notification = %Notification{user_id: "user-123"}
      assert NotificationPolicy.belongs_to_user?(notification, "user-456") == false
    end
  end

  describe "can_mark_as_read?/2" do
    test "returns true when notification belongs to user and is unread" do
      notification = %Notification{user_id: "user-123", read: false}
      assert NotificationPolicy.can_mark_as_read?(notification, "user-123") == true
    end

    test "returns false when notification does not belong to user" do
      notification = %Notification{user_id: "user-123", read: false}
      assert NotificationPolicy.can_mark_as_read?(notification, "user-456") == false
    end

    test "returns false when notification is already read" do
      notification = %Notification{user_id: "user-123", read: true}
      assert NotificationPolicy.can_mark_as_read?(notification, "user-123") == false
    end

    test "returns false when notification does not belong to user and is already read" do
      notification = %Notification{user_id: "user-123", read: true}
      assert NotificationPolicy.can_mark_as_read?(notification, "user-456") == false
    end
  end

  describe "readable?/1" do
    test "returns true when notification is unread" do
      notification = %Notification{read: false}
      assert NotificationPolicy.readable?(notification) == true
    end

    test "returns false when notification is already read" do
      notification = %Notification{read: true}
      assert NotificationPolicy.readable?(notification) == false
    end
  end

  describe "valid_type?/1" do
    test "returns true for workspace_invitation type" do
      assert NotificationPolicy.valid_type?("workspace_invitation") == true
    end

    test "returns false for unknown type" do
      assert NotificationPolicy.valid_type?("unknown") == false
    end

    test "returns false for nil type" do
      assert NotificationPolicy.valid_type?(nil) == false
    end

    test "returns false for empty string" do
      assert NotificationPolicy.valid_type?("") == false
    end
  end
end
