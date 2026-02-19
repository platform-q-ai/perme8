defmodule Identity.Domain.Events.MemberInvitedTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Events.MemberInvited

  @valid_attrs %{
    aggregate_id: "ws-123:user-456",
    actor_id: "inviter-789",
    user_id: "user-456",
    workspace_id: "ws-123",
    workspace_name: "Test Workspace",
    invited_by_name: "John Doe",
    role: "member"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert MemberInvited.event_type() == "identity.member_invited"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert MemberInvited.aggregate_type() == "workspace_member"
    end
  end

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event = MemberInvited.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "identity.member_invited"
      assert event.aggregate_type == "workspace_member"
      assert event.aggregate_id == "ws-123:user-456"
      assert event.actor_id == "inviter-789"
      assert event.metadata == %{}
    end

    test "sets all custom fields correctly" do
      event = MemberInvited.new(@valid_attrs)

      assert event.user_id == "user-456"
      assert event.workspace_id == "ws-123"
      assert event.workspace_name == "Test Workspace"
      assert event.invited_by_name == "John Doe"
      assert event.role == "member"
    end

    test "generates unique event_id for each call" do
      event1 = MemberInvited.new(@valid_attrs)
      event2 = MemberInvited.new(@valid_attrs)

      assert event1.event_id != event2.event_id
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        MemberInvited.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when workspace_id is missing" do
      assert_raise ArgumentError, fn ->
        MemberInvited.new(%{
          aggregate_id: "123",
          actor_id: "123",
          user_id: "u-1",
          workspace_name: "WS",
          invited_by_name: "John",
          role: "member"
        })
      end
    end

    test "allows custom metadata" do
      event = MemberInvited.new(Map.put(@valid_attrs, :metadata, %{source: "api"}))

      assert event.metadata == %{source: "api"}
    end
  end
end
