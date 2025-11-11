defmodule Jarga.Agents.ChatMessageTest do
  @moduledoc """
  Tests for ChatMessage schema.
  """
  use Jarga.DataCase, async: true

  import Jarga.AgentsFixtures

  alias Jarga.Agents.ChatMessage

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "Hello, how can I help?"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :chat_session_id) == session.id
      assert get_change(changeset, :role) == "user"
      assert get_change(changeset, :content) == "Hello, how can I help?"
    end

    test "valid changeset with assistant role" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "assistant",
        content: "I'm here to help!"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :role) == "assistant"
    end

    test "valid changeset with context_chunks" do
      session = chat_session_fixture()
      chunk_id1 = Ecto.UUID.generate()
      chunk_id2 = Ecto.UUID.generate()

      attrs = %{
        chat_session_id: session.id,
        role: "assistant",
        content: "Based on the documents...",
        context_chunks: [chunk_id1, chunk_id2]
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :context_chunks) == [chunk_id1, chunk_id2]
    end

    test "invalid without chat_session_id" do
      attrs = %{
        role: "user",
        content: "Hello"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).chat_session_id
    end

    test "invalid without role" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        content: "Hello"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "invalid without content" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "invalid with invalid role" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "invalid",
        content: "Hello"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "content is trimmed of whitespace" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "  Hello World  "
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      assert get_change(changeset, :content) == "Hello World"
    end

    test "empty content after trim is invalid" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "   "
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "context_chunks defaults to empty array" do
      session = chat_session_fixture()

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "Hello"
      }

      changeset = ChatMessage.changeset(%ChatMessage{}, attrs)

      # Default value is applied at database level, so no change in changeset
      assert get_change(changeset, :context_chunks) == nil
    end
  end
end
