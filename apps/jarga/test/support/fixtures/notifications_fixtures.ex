defmodule Jarga.NotificationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Notifications` context.
  """

  use Boundary, top_level?: true, deps: [Jarga.Notifications], exports: []

  alias Jarga.Notifications

  def valid_workspace_invitation_notification_attributes(user, attrs \\ %{}) do
    # Extract data if passed as nested structure
    data = get_data_from_attrs(attrs)

    %{
      user_id: user.id,
      workspace_id: get_field(data, attrs, :workspace_id, Ecto.UUID.generate()),
      workspace_name: get_field(data, attrs, :workspace_name, "Test Workspace"),
      invited_by_name: get_field(data, attrs, :invited_by_name, "Test User"),
      role: get_field(data, attrs, :role, "member")
    }
  end

  defp get_data_from_attrs(attrs) do
    attrs[:data] || attrs["data"] || %{}
  end

  defp get_field(data, attrs, key, default) do
    data[key] || attrs[key] || default
  end

  def notification_fixture(user, attrs \\ %{}) do
    # Extract read status and inserted_at before transforming attrs
    should_mark_read = attrs[:read] == true
    custom_inserted_at = attrs[:inserted_at]

    # Create the notification
    notification_attrs = valid_workspace_invitation_notification_attributes(user, attrs)

    {:ok, notification} =
      Notifications.create_workspace_invitation_notification(notification_attrs)

    # Update notification if needed (for test data setup)
    notification =
      cond do
        should_mark_read and custom_inserted_at ->
          # Update both read status and inserted_at
          update_notification_for_test(notification, %{
            read: true,
            read_at: DateTime.utc_now() |> DateTime.truncate(:second),
            inserted_at: custom_inserted_at
          })

        should_mark_read ->
          # Just mark as read
          {:ok, updated} = Notifications.mark_as_read(notification.id, user.id)
          updated

        custom_inserted_at ->
          # Just update inserted_at
          update_notification_for_test(notification, %{inserted_at: custom_inserted_at})

        true ->
          notification
      end

    notification
  end

  # Helper to update notification fields directly in the database (for test setup only)
  defp update_notification_for_test(notification, changes) do
    # Convert NaiveDateTime to DateTime if present
    changes =
      if changes[:inserted_at] && is_struct(changes.inserted_at, NaiveDateTime) do
        Map.put(changes, :inserted_at, DateTime.from_naive!(changes.inserted_at, "Etc/UTC"))
      else
        changes
      end

    Notifications.update_for_test(notification, changes)
  end
end
