defmodule Jarga.Chat.Infrastructure.Schemas.SessionSchemaTest do
  use Jarga.DataCase, async: true

  alias Jarga.Chat.Infrastructure.Schemas.SessionSchema

  @moduledoc """
  Tests for the SessionSchema Ecto schema.

  This tests the infrastructure layer schema, not the pure domain entity.
  """

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

    test "valid changeset with only user_id (required field)" do
      attrs = %{user_id: Ecto.UUID.generate()}
      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :user_id) == attrs.user_id
    end

    test "invalid changeset when user_id is missing" do
      attrs = %{title: "Chat"}
      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "trims whitespace from title" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        title: "  Spaced Title  "
      }

      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :title) == "Spaced Title"
    end

    test "validates title max length" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        title: String.duplicate("a", 256)
      }

      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).title
    end

    test "accepts title at max length" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        title: String.duplicate("a", 255)
      }

      changeset = SessionSchema.changeset(%SessionSchema{}, attrs)

      assert changeset.valid?
    end
  end

  describe "title_changeset/2" do
    test "updates title only" do
      session = %SessionSchema{user_id: Ecto.UUID.generate()}
      attrs = %{title: "New Title"}

      changeset = SessionSchema.title_changeset(session, attrs)

      assert changeset.valid?
      assert get_change(changeset, :title) == "New Title"
    end

    test "trims whitespace from title" do
      session = %SessionSchema{user_id: Ecto.UUID.generate()}
      attrs = %{title: "  Trimmed  "}

      changeset = SessionSchema.title_changeset(session, attrs)

      assert changeset.valid?
      assert get_change(changeset, :title) == "Trimmed"
    end

    test "validates title max length" do
      session = %SessionSchema{user_id: Ecto.UUID.generate()}
      attrs = %{title: String.duplicate("a", 256)}

      changeset = SessionSchema.title_changeset(session, attrs)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).title
    end
  end
end
