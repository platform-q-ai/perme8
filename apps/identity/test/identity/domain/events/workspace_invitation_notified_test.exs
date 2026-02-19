defmodule Identity.Domain.Events.WorkspaceInvitationNotifiedTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Events.WorkspaceInvitationNotified

  @valid_attrs %{
    aggregate_id: "ws-123:user-456",
    actor_id: "inviter-789",
    workspace_id: "ws-123",
    target_user_id: "user-456",
    workspace_name: "Test Workspace",
    invited_by_name: "John"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert WorkspaceInvitationNotified.event_type() == "identity.workspace_invitation_notified"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert WorkspaceInvitationNotified.aggregate_type() == "workspace_member"
    end
  end

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event = WorkspaceInvitationNotified.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "identity.workspace_invitation_notified"
      assert event.aggregate_type == "workspace_member"
      assert event.aggregate_id == "ws-123:user-456"
      assert event.actor_id == "inviter-789"
      assert event.metadata == %{}
    end

    test "sets all custom fields correctly" do
      event = WorkspaceInvitationNotified.new(@valid_attrs)

      assert event.workspace_id == "ws-123"
      assert event.target_user_id == "user-456"
      assert event.workspace_name == "Test Workspace"
      assert event.invited_by_name == "John"
      assert event.role == nil
    end

    test "sets optional role field" do
      event = WorkspaceInvitationNotified.new(Map.put(@valid_attrs, :role, "admin"))

      assert event.role == "admin"
    end

    test "generates unique event_id for each call" do
      event1 = WorkspaceInvitationNotified.new(@valid_attrs)
      event2 = WorkspaceInvitationNotified.new(@valid_attrs)

      assert event1.event_id != event2.event_id
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceInvitationNotified.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when workspace_id is missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceInvitationNotified.new(%{
          aggregate_id: "123",
          actor_id: "123",
          target_user_id: "user-456",
          workspace_name: "WS",
          invited_by_name: "John"
        })
      end
    end

    test "raises when target_user_id is missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceInvitationNotified.new(%{
          aggregate_id: "123",
          actor_id: "123",
          workspace_id: "ws-123",
          workspace_name: "WS",
          invited_by_name: "John"
        })
      end
    end

    test "raises when workspace_name is missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceInvitationNotified.new(%{
          aggregate_id: "123",
          actor_id: "123",
          workspace_id: "ws-123",
          target_user_id: "user-456",
          invited_by_name: "John"
        })
      end
    end

    test "raises when invited_by_name is missing" do
      assert_raise ArgumentError, fn ->
        WorkspaceInvitationNotified.new(%{
          aggregate_id: "123",
          actor_id: "123",
          workspace_id: "ws-123",
          target_user_id: "user-456",
          workspace_name: "WS"
        })
      end
    end

    test "allows custom metadata" do
      event = WorkspaceInvitationNotified.new(Map.put(@valid_attrs, :metadata, %{source: "api"}))

      assert event.metadata == %{source: "api"}
    end
  end
end
