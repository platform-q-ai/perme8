defmodule JargaWeb.NotificationsLive.OnMount do
  @moduledoc """
  LiveView hook for notification-related functionality.

  Subscribes to user-specific structured event topic and handles
  real-time notification updates by forwarding them to the NotificationBell component.
  """

  alias Notifications.Domain.Events.NotificationCreated
  alias Notifications

  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    # Subscribe to structured event topic if user is authenticated
    socket =
      if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
        user_id = socket.assigns.current_scope.user.id

        if connected?(socket) do
          Perme8.Events.subscribe("events:user:#{user_id}")
        end

        # Attach handle_info callback to forward notification events to the component
        attach_hook(socket, :handle_notification_updates, :handle_info, fn
          %NotificationCreated{} = event, socket ->
            # Forward the update to the NotificationBell component with force_reload
            {:cont, handle_notification_created(event, socket)}

          _other, socket ->
            {:cont, socket}
        end)
      else
        socket
      end

    {:cont, socket}
  end

  defp handle_notification_created(event, socket) do
    user = socket.assigns.current_scope.user

    send_update(JargaWeb.NotificationsLive.NotificationBell,
      id: "notification-bell-topbar",
      current_user: user,
      force_reload: true
    )

    event_payload =
      case Notifications.get_notification(event.notification_id, user.id) do
        notification when not is_nil(notification) ->
          %{
            title: notification.title,
            body: notification.body,
            type: notification.type
          }

        _ ->
          nil
      end

    case event_payload do
      nil -> socket
      payload -> push_event(socket, "browser_notification", payload)
    end
  end
end
