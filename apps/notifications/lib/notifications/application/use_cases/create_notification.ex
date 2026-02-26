defmodule Notifications.Application.UseCases.CreateNotification do
  @moduledoc """
  Creates a notification for a user.

  Generic notification creation that works for any notification type.
  For `workspace_invitation` type, auto-builds title and body from
  data fields if not explicitly provided.
  """

  alias Notifications.Domain.Events.NotificationCreated

  @default_notification_repository Notifications.Infrastructure.Repositories.NotificationRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Creates a notification.

  ## Parameters
    * `:user_id` - The ID of the user receiving the notification
    * `:type` - The notification type (e.g., "workspace_invitation")
    * `:title` - Notification title (auto-built for workspace_invitation if omitted)
    * `:body` - Notification body (auto-built for workspace_invitation if omitted)
    * `:data` - Additional data map (optional)

  ## Options
    * `:notification_repository` - Repository module (default: NotificationRepository)
    * `:event_bus` - Event bus module (default: EventBus)
    * `:event_bus_opts` - Options passed to event_bus.emit/2

  Returns `{:ok, notification}` on success.
  Returns `{:error, changeset}` on validation failure.
  """
  def execute(params, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    notification_attrs = build_attrs(params)

    case notification_repository.create(notification_attrs) do
      {:ok, notification} = result ->
        emit_notification_created_event(notification, event_bus, event_bus_opts)
        result

      error ->
        error
    end
  end

  defp build_attrs(params) do
    type = get_param(params, :type)
    data = get_param(params, :data) || %{}

    %{
      user_id: get_param(params, :user_id),
      type: type,
      title: get_param(params, :title) || auto_title(type, data),
      body: get_param(params, :body) || auto_body(type, data),
      data: data
    }
  end

  defp auto_title("workspace_invitation", data) do
    workspace_name = get_param(data, :workspace_name)
    "Workspace Invitation: #{workspace_name}"
  end

  defp auto_title(_type, _data), do: nil

  defp auto_body("workspace_invitation", data) do
    invited_by_name = get_param(data, :invited_by_name)
    workspace_name = get_param(data, :workspace_name)
    role = get_param(data, :role)
    "#{invited_by_name} has invited you to join #{workspace_name} as a #{role}."
  end

  defp auto_body(_type, _data), do: nil

  defp get_param(params, key) when is_map(params) do
    params[key] || params[to_string(key)]
  end

  defp emit_notification_created_event(notification, event_bus, event_bus_opts) do
    event =
      NotificationCreated.new(%{
        aggregate_id: notification.id,
        actor_id: notification.user_id,
        notification_id: notification.id,
        user_id: notification.user_id,
        type: notification.type,
        target_user_id: notification.user_id
      })

    event_bus.emit(event, event_bus_opts)
  end
end
