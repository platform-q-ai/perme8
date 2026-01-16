defmodule JargaWeb.NotificationsLive.OnMount do
  @moduledoc """
  LiveView hook for notification-related functionality.

  Subscribes to user-specific notification PubSub topic and handles
  real-time notification updates by forwarding them to the NotificationBell component.
  """

  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    # Subscribe to notifications PubSub topic if user is authenticated
    socket =
      if socket.assigns[:current_scope] && socket.assigns.current_scope.user do
        user_id = socket.assigns.current_scope.user.id

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Jarga.PubSub, "user:#{user_id}:notifications")
        end

        # Attach handle_info callback to forward notification messages to the component
        attach_hook(socket, :handle_notification_updates, :handle_info, fn
          {:new_notification, _notification}, socket ->
            # Forward the update to the NotificationBell component with force_reload
            send_update(JargaWeb.NotificationsLive.NotificationBell,
              id: "notification-bell-topbar",
              current_user: socket.assigns.current_scope.user,
              force_reload: true
            )

            {:cont, socket}

          _other, socket ->
            {:cont, socket}
        end)
      else
        socket
      end

    {:cont, socket}
  end
end
