defmodule Identity.Domain.Events.MemberRemovedTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Events.MemberRemoved

  @valid_attrs %{
    aggregate_id: "ws-123:user-456",
    actor_id: "admin-789",
    workspace_id: "ws-123",
    target_user_id: "user-456"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert MemberRemoved.event_type() == "identity.member_removed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert MemberRemoved.aggregate_type() == "workspace_member"
    end
  end

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event = MemberRemoved.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "identity.member_removed"
      assert event.aggregate_type == "workspace_member"
      assert event.aggregate_id == "ws-123:user-456"
      assert event.actor_id == "admin-789"
      assert event.metadata == %{}
    end

    test "sets all custom fields correctly" do
      event = MemberRemoved.new(@valid_attrs)

      assert event.workspace_id == "ws-123"
      assert event.target_user_id == "user-456"
    end

    test "generates unique event_id for each call" do
      event1 = MemberRemoved.new(@valid_attrs)
      event2 = MemberRemoved.new(@valid_attrs)

      assert event1.event_id != event2.event_id
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        MemberRemoved.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when workspace_id is missing" do
      assert_raise ArgumentError, fn ->
        MemberRemoved.new(%{
          aggregate_id: "123",
          actor_id: "123",
          target_user_id: "user-456"
        })
      end
    end

    test "raises when target_user_id is missing" do
      assert_raise ArgumentError, fn ->
        MemberRemoved.new(%{
          aggregate_id: "123",
          actor_id: "123",
          workspace_id: "ws-123"
        })
      end
    end

    test "allows custom metadata" do
      event = MemberRemoved.new(Map.put(@valid_attrs, :metadata, %{source: "api"}))

      assert event.metadata == %{source: "api"}
    end
  end
end
