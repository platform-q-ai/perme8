defmodule Notifications.Test.Fixtures.NotificationsFixtures do
  @moduledoc """
  Test helpers for creating notification entities directly via Repo.

  Creates notifications directly via `Notifications.Repo.insert/1` to avoid
  triggering event emission that would happen through use cases.
  """

  alias Notifications.Infrastructure.Schemas.NotificationSchema
  alias Notifications.Repo

  @doc """
  Returns a map of valid notification attributes, with optional overrides.

  A `user_id` must be provided either in `overrides` or the caller must
  merge one in — the notifications table has a foreign key to users.
  """
  def valid_notification_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        type: "workspace_invitation",
        title: "Workspace Invitation: Test Workspace",
        body: "Test User has invited you to join Test Workspace as a member.",
        data: %{
          "workspace_id" => Ecto.UUID.generate(),
          "workspace_name" => "Test Workspace",
          "invited_by_name" => "Test User",
          "role" => "member"
        }
      },
      overrides
    )
  end

  @doc """
  Creates a notification directly in the database via Repo.insert.

  Does NOT trigger event emission (bypasses use cases).
  Requires a valid `user_id` (foreign key to users table).
  """
  def notification_fixture(user_id, overrides \\ %{}) when is_binary(user_id) do
    attrs = valid_notification_attrs(Map.put(overrides, :user_id, user_id))

    {:ok, notification} =
      attrs
      |> NotificationSchema.create_changeset()
      |> Repo.insert()

    notification
  end
end
