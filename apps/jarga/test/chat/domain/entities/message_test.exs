defmodule Jarga.Chat.Domain.Entities.MessageTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Domain.Entities.Message

  @moduledoc """
  Tests for the Message domain entity.

  This is a pure value object with no infrastructure dependencies.
  """

  describe "new/1" do
    test "creates a message from attributes" do
      attrs = %{
        chat_session_id: "session-123",
        role: "user",
        content: "Hello, AI!",
        context_chunks: ["chunk-1", "chunk-2"]
      }

      message = Message.new(attrs)

      assert message.chat_session_id == "session-123"
      assert message.role == "user"
      assert message.content == "Hello, AI!"
      assert message.context_chunks == ["chunk-1", "chunk-2"]
    end

    test "creates message with minimal attributes" do
      attrs = %{
        chat_session_id: "session-123",
        role: "assistant",
        content: "How can I help?"
      }

      message = Message.new(attrs)

      assert message.chat_session_id == "session-123"
      assert message.role == "assistant"
      assert message.content == "How can I help?"
      assert message.context_chunks == []
    end
  end

  describe "from_schema/1" do
    test "converts schema to domain entity" do
      # Simulate an Ecto schema struct
      schema = %{
        __struct__: SomeMessageSchema,
        id: "message-123",
        chat_session_id: "session-456",
        role: "user",
        content: "Test message",
        context_chunks: ["chunk-1"],
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 01:00:00Z]
      }

      message = Message.from_schema(schema)

      assert message.id == "message-123"
      assert message.chat_session_id == "session-456"
      assert message.role == "user"
      assert message.content == "Test message"
      assert message.context_chunks == ["chunk-1"]
      assert message.inserted_at == ~U[2024-01-01 00:00:00Z]
      assert message.updated_at == ~U[2024-01-01 01:00:00Z]
    end

    test "handles nil context_chunks" do
      schema = %{
        __struct__: SomeMessageSchema,
        id: "message-123",
        chat_session_id: "session-456",
        role: "assistant",
        content: "Response",
        context_chunks: nil,
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      message = Message.from_schema(schema)
      assert message.context_chunks == []
    end
  end
end
