defmodule Jarga.Chat.Domain.Events.ChatSessionDeletedTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Domain.Events.ChatSessionDeleted

  @valid_attrs %{
    aggregate_id: "sess-123",
    actor_id: "user-123",
    session_id: "sess-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert ChatSessionDeleted.event_type() == "chat.chat_session_deleted"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert ChatSessionDeleted.aggregate_type() == "chat_session"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = ChatSessionDeleted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "chat.chat_session_deleted"
      assert event.aggregate_type == "chat_session"
      assert event.session_id == "sess-123"
      assert event.user_id == "user-123"
    end

    test "workspace_id is optional" do
      event = ChatSessionDeleted.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        ChatSessionDeleted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
