defmodule JargaWeb.ChatLive.MessageHandlers do
  @moduledoc """
  Provides reusable message handlers for LiveViews that include the global chat panel.

  This module should be imported into any LiveView that uses the admin layout
  (which includes the chat panel component).

  ## Usage

      defmodule MyAppWeb.SomeLive do
        use MyAppWeb, :live_view
        import JargaWeb.ChatLive.MessageHandlers

        # Your other callbacks...

        # Add chat panel message handlers
        handle_chat_messages()
      end
  """

  @doc """
  Defines handle_info callbacks for chat panel streaming messages and handle_event for agent selection.

  This macro injects the necessary handle_info/2 callbacks that forward
  streaming messages from the LLM client to the global chat panel component,
  notification events to the notification bell component, and handle_event/3
  for agent selection events from the JavaScript hook.
  """
  defmacro handle_chat_messages do
    quote do
      @impl true
      def handle_event("agent-selected", %{"agent_id" => agent_id}, socket) do
        # Forward agent selection to chat panel component
        Phoenix.LiveView.send_update(JargaWeb.ChatLive.Panel,
          id: "global-chat-panel",
          selected_agent_id: agent_id
        )

        {:noreply, socket}
      end

      @impl true
      def handle_info({:chunk, chunk}, socket) do
        Phoenix.LiveView.send_update(JargaWeb.ChatLive.Panel,
          id: "global-chat-panel",
          chunk: chunk
        )

        {:noreply, socket}
      end

      @impl true
      def handle_info({:done, full_response}, socket) do
        Phoenix.LiveView.send_update(JargaWeb.ChatLive.Panel,
          id: "global-chat-panel",
          done: full_response
        )

        {:noreply, socket}
      end

      @impl true
      def handle_info({:error, reason}, socket) do
        Phoenix.LiveView.send_update(JargaWeb.ChatLive.Panel,
          id: "global-chat-panel",
          error: reason
        )

        {:noreply, socket}
      end

      @impl true
      def handle_info({:assistant_response, _response}, socket) do
        # This is sent for test assertions - ignore in production
        {:noreply, socket}
      end

      @impl true
      def handle_info({:new_notification, _notification}, socket) do
        # Notification received - update the NotificationBell LiveComponent
        Phoenix.LiveView.send_update(JargaWeb.NotificationsLive.NotificationBell,
          id: "notification-bell",
          current_user: socket.assigns.current_scope.user
        )

        {:noreply, socket}
      end
    end
  end
end
