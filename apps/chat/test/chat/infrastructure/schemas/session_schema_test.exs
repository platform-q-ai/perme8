defmodule Chat.Infrastructure.Schemas.SessionSchemaTest do
  use Chat.DataCase, async: true

  alias Chat.Infrastructure.Schemas.SessionSchema

  describe "changeset/2" do
    test "valid changeset with all fields" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        workspace_id: Ecto.UUID.generate(),
        project_id: Ecto.UUID.generate(),
        title: "My Chat Session"
      }

      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :user_id) == attrs.user_id
      assert get_change(changeset, :workspace_id) == attrs.workspace_id
      assert get_change(changeset, :project_id) == attrs.project_id
      assert get_change(changeset, :title) == "My Chat Session"
    end

    test "invalid changeset when user_id is missing" do
      changeset = SessionSchema.changeset(%SessionSchema{}, %{title: "Chat"})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "trims whitespace from title" do
      attrs = %{user_id: Ecto.UUID.generate(), title: "  Spaced Title  "}
      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :title) == "Spaced Title"
    end

    test "validates title max length 255" do
      attrs = %{user_id: Ecto.UUID.generate(), title: String.duplicate("a", 256)}
      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).title
    end
  end

  describe "title_changeset/2" do
    test "updates title only" do
      session = %SessionSchema{user_id: Ecto.UUID.generate()}
      changeset = SessionSchema.title_changeset(session, %{title: "New Title"})

      assert changeset.valid?
      assert get_change(changeset, :title) == "New Title"
    end
  end
end
