defmodule Jarga.Notifications.Infrastructure.Schemas.NotificationSchemaTest do
  use ExUnit.Case, async: true

  alias Jarga.Notifications.Infrastructure.Schemas.NotificationSchema

  describe "create_changeset/1" do
    test "validates required fields" do
      changeset = NotificationSchema.create_changeset(%{})

      refute changeset.valid?

      assert %{user_id: ["can't be blank"], type: ["can't be blank"], title: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "validates notification type is known" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        type: "invalid_type",
        title: "Test Notification"
      }

      changeset = NotificationSchema.create_changeset(attrs)

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid workspace_invitation notification" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        type: "workspace_invitation",
        title: "Test Notification",
        body: "Test body",
        data: %{"workspace_id" => Ecto.UUID.generate()}
      }

      changeset = NotificationSchema.create_changeset(attrs)

      assert changeset.valid?
    end

    test "defaults read to false and data to empty map" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        type: "workspace_invitation",
        title: "Test Notification"
      }

      changeset = NotificationSchema.create_changeset(attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :read) == false
      assert Ecto.Changeset.get_field(changeset, :data) == %{}
    end
  end

  describe "mark_read_changeset/1" do
    test "marks notification as read with timestamp" do
      notification = %NotificationSchema{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        type: "workspace_invitation",
        title: "Test",
        read: false,
        read_at: nil
      }

      changeset = NotificationSchema.mark_read_changeset(notification)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :read) == true
      assert %DateTime{} = Ecto.Changeset.get_change(changeset, :read_at)
    end
  end

  describe "mark_action_taken_changeset/1" do
    test "marks action as taken with timestamp" do
      notification = %NotificationSchema{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        type: "workspace_invitation",
        title: "Test",
        action_taken_at: nil
      }

      changeset = NotificationSchema.mark_action_taken_changeset(notification)

      assert changeset.valid?
      assert %DateTime{} = Ecto.Changeset.get_change(changeset, :action_taken_at)
    end
  end

  # Helper function to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
