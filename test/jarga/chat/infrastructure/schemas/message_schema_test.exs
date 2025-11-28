defmodule Jarga.Chat.Infrastructure.Schemas.MessageSchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Chat.Infrastructure.Schemas.MessageSchema

  @moduledoc """
  Tests for the MessageSchema Ecto schema.

  This tests the infrastructure layer schema, not the pure domain entity.
  """

  describe "changeset/2" do
    test "valid changeset with all fields" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "user",
        content: "Hello, assistant!",
        context_chunks: [Ecto.UUID.generate(), Ecto.UUID.generate()]
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :chat_session_id) == attrs.chat_session_id
      assert get_change(changeset, :role) == "user"
      assert get_change(changeset, :content) == "Hello, assistant!"
      assert get_change(changeset, :context_chunks) == attrs.context_chunks
    end

    test "valid changeset without context_chunks" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "assistant",
        content: "I can help you with that."
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :chat_session_id) == attrs.chat_session_id
      assert get_change(changeset, :role) == "assistant"
      assert get_change(changeset, :content) == "I can help you with that."
    end

    test "invalid when chat_session_id is missing" do
      attrs = %{role: "user", content: "Hello"}
      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).chat_session_id
    end

    test "invalid when role is missing" do
      attrs = %{chat_session_id: Ecto.UUID.generate(), content: "Hello"}
      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "invalid when content is missing" do
      attrs = %{chat_session_id: Ecto.UUID.generate(), role: "user"}
      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "invalid when role is not 'user' or 'assistant'" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "system",
        content: "Hello"
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "valid when role is 'user'" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "user",
        content: "Question"
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)
      assert changeset.valid?
    end

    test "valid when role is 'assistant'" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "assistant",
        content: "Answer"
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)
      assert changeset.valid?
    end

    test "trims content whitespace" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "user",
        content: "  Spaces around  "
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :content) == "Spaces around"
    end

    test "sets content to nil when it's only whitespace" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "user",
        content: "   "
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "invalid when content becomes empty after trimming" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "user",
        content: ""
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end
  end
end
