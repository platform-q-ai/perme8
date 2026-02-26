defmodule Identity.Domain.Events.MemberJoinedTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Events.MemberJoined

  @valid_attrs %{
    aggregate_id: "ws-123:user-456",
    actor_id: "user-456",
    workspace_id: "ws-123",
    target_user_id: "user-456"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert MemberJoined.event_type() == "identity.member_joined"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert MemberJoined.aggregate_type() == "workspace_member"
    end
  end

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event = MemberJoined.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "identity.member_joined"
      assert event.aggregate_type == "workspace_member"
      assert event.aggregate_id == "ws-123:user-456"
      assert event.actor_id == "user-456"
      assert event.metadata == %{}
    end

    test "sets target_user_id correctly" do
      event = MemberJoined.new(@valid_attrs)

      assert event.target_user_id == "user-456"
    end

    test "generates unique event_id for each call" do
      event1 = MemberJoined.new(@valid_attrs)
      event2 = MemberJoined.new(@valid_attrs)

      assert event1.event_id != event2.event_id
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        MemberJoined.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when target_user_id is missing" do
      assert_raise ArgumentError, fn ->
        MemberJoined.new(%{
          aggregate_id: "123",
          actor_id: "123",
          workspace_id: "ws-1"
        })
      end
    end

    test "allows custom metadata" do
      event = MemberJoined.new(Map.put(@valid_attrs, :metadata, %{source: "notification_bell"}))

      assert event.metadata == %{source: "notification_bell"}
    end
  end
end
