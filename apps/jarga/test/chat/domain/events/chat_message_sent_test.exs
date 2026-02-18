defmodule Jarga.Chat.Domain.Events.ChatMessageSentTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Domain.Events.ChatMessageSent

  @valid_attrs %{
    aggregate_id: "sess-123",
    actor_id: "user-123",
    message_id: "msg-123",
    session_id: "sess-123",
    user_id: "user-123",
    role: "user"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert ChatMessageSent.event_type() == "chat.chat_message_sent"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert ChatMessageSent.aggregate_type() == "chat_session"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = ChatMessageSent.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "chat.chat_message_sent"
      assert event.aggregate_type == "chat_session"
      assert event.message_id == "msg-123"
      assert event.session_id == "sess-123"
      assert event.user_id == "user-123"
      assert event.role == "user"
    end

    test "workspace_id is optional" do
      event = ChatMessageSent.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        ChatMessageSent.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
