defmodule Jarga.Chat.Domain.Events.ChatSessionStartedTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Domain.Events.ChatSessionStarted

  @valid_attrs %{
    aggregate_id: "sess-123",
    actor_id: "user-123",
    session_id: "sess-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert ChatSessionStarted.event_type() == "chat.chat_session_started"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert ChatSessionStarted.aggregate_type() == "chat_session"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = ChatSessionStarted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "chat.chat_session_started"
      assert event.aggregate_type == "chat_session"
      assert event.session_id == "sess-123"
      assert event.user_id == "user-123"
    end

    test "workspace_id is optional and defaults to nil" do
      event = ChatSessionStarted.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "agent_id is optional and defaults to nil" do
      event = ChatSessionStarted.new(@valid_attrs)
      assert event.agent_id == nil
    end

    test "accepts optional fields" do
      event =
        ChatSessionStarted.new(
          Map.merge(@valid_attrs, %{workspace_id: "ws-123", agent_id: "agent-123"})
        )

      assert event.workspace_id == "ws-123"
      assert event.agent_id == "agent-123"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        ChatSessionStarted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
