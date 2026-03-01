defmodule Chat.Infrastructure.Schemas.MessageSchemaTest do
  use Chat.DataCase, async: true

  alias Chat.Infrastructure.Schemas.MessageSchema

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        chat_session_id: Ecto.UUID.generate(),
        role: "user",
        content: "Hello, assistant!"
      }

      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :chat_session_id) == attrs.chat_session_id
      assert get_change(changeset, :role) == "user"
      assert get_change(changeset, :content) == "Hello, assistant!"
    end

    test "invalid when required fields are missing" do
      changeset = MessageSchema.changeset(%MessageSchema{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).chat_session_id
      assert "can't be blank" in errors_on(changeset).role
      assert "can't be blank" in errors_on(changeset).content
    end

    test "invalid role when not user or assistant" do
      attrs = %{chat_session_id: Ecto.UUID.generate(), role: "system", content: "x"}
      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "trims content and rejects blank content" do
      attrs = %{chat_session_id: Ecto.UUID.generate(), role: "user", content: "   "}
      changeset = MessageSchema.changeset(%MessageSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end
  end
end
