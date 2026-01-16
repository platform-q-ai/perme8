defmodule JargaWeb.NotificationsLive.NotificationBell do
  @moduledoc """
  LiveComponent for displaying a notification bell with unread count and dropdown.
  """
  use JargaWeb, :live_component

  alias Jarga.Notifications

  @impl true
  def mount(socket) do
    {:ok, stream(socket, :notifications, [])}
  end

  @impl true
  def update(assigns, socket) do
    # Check if this is a forced reload (from PubSub)
    force_reload = Map.get(assigns, :force_reload, false)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show_dropdown, fn -> false end)
      |> assign_new(:unread_count, fn -> 0 end)
      |> assign_new(:notifications_loaded, fn -> false end)
      |> maybe_load_notifications(force_reload)

    {:ok, socket}
  end

  defp maybe_load_notifications(socket, force_reload) do
    if force_reload or not socket.assigns.notifications_loaded do
      load_notifications(socket)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative" id="notification-bell">
      <!-- Bell Icon Button -->
      <button
        type="button"
        id="notification-bell-toggle"
        phx-click="toggle_dropdown"
        phx-target={@myself}
        class="btn btn-ghost btn-circle relative"
        aria-label="Notifications"
      >
        <.icon name="hero-bell" class="size-6" />
        <%= if @unread_count > 0 do %>
          <span
            id="notification-bell-badge"
            class="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white transform translate-x-1/2 -translate-y-1/2 bg-error rounded-full"
          >
            {if @unread_count > 99, do: "99+", else: @unread_count}
          </span>
        <% end %>
      </button>
      
    <!-- Dropdown -->
      <div
        id="notification-bell-dropdown"
        class={"absolute right-0 mt-2 w-96 bg-base-100 border border-base-300 rounded-lg shadow-xl z-50 #{if !@show_dropdown, do: "hidden"}"}
        phx-click-away="close_dropdown"
        phx-target={@myself}
      >
        <!-- Header -->
        <div class="flex items-center justify-between px-4 py-3 border-b border-base-300">
          <h3 class="font-semibold text-lg">Notifications</h3>
          <%= if @unread_count > 0 do %>
            <button
              type="button"
              id="notification-mark-all-read-btn"
              phx-click="mark_all_read"
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
            >
              Mark all read
            </button>
          <% end %>
        </div>
        
    <!-- Notifications List -->
        <div id="notifications" phx-update="stream" class="max-h-96 overflow-y-auto">
          <div
            id="notifications-empty-state"
            class="hidden only:block px-4 py-8 text-center text-base-content/70"
          >
            <.icon name="hero-bell-slash" class="size-12 mx-auto mb-2 opacity-50" />
            <p>No notifications</p>
          </div>
          <div :for={{dom_id, notification} <- @streams.notifications} id={dom_id}>
            <.notification_item
              id={"notification-item-#{notification.id}"}
              notification={notification}
              myself={@myself}
              current_user={@current_user}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :notification, :map, required: true
  attr :myself, :any, required: true
  attr :current_user, :map, required: true

  defp notification_item(assigns) do
    ~H"""
    <div
      id={@id}
      data-notification-id={@notification.id}
      class={"px-4 py-3 border-b border-base-300 hover:bg-base-200 #{if !@notification.read, do: "bg-base-200/50"}"}
    >
      <div class="flex items-start gap-3">
        <!-- Icon -->
        <div class="flex-shrink-0 mt-1">
          <%= if @notification.type == "workspace_invitation" do %>
            <.icon name="hero-briefcase" class="size-5 text-primary" />
          <% end %>
        </div>
        
    <!-- Content -->
        <div class="flex-1 min-w-0">
          <p class="font-medium text-sm">{@notification.title}</p>
          <p class="text-sm text-base-content/70 mt-1">{@notification.body}</p>
          
    <!-- Workspace Invitation Actions -->
          <%= if @notification.type == "workspace_invitation" && is_nil(@notification.action_taken_at) do %>
            <div class="flex gap-2 mt-3">
              <button
                type="button"
                id={"notification-accept-btn-#{@notification.id}"}
                phx-click="accept_invitation"
                phx-value-notification-id={@notification.id}
                phx-target={@myself}
                class="btn btn-primary btn-xs"
              >
                Accept
              </button>
              <button
                type="button"
                id={"notification-decline-btn-#{@notification.id}"}
                phx-click="decline_invitation"
                phx-value-notification-id={@notification.id}
                phx-target={@myself}
                class="btn btn-ghost btn-xs"
              >
                Decline
              </button>
            </div>
          <% end %>

          <%= if @notification.action_taken_at do %>
            <p id={"notification-action-status-#{@notification.id}"} class="text-xs text-success mt-2">
              ✓ Invitation {case @notification.data["action"] do
                "accepted" -> "accepted"
                "declined" -> "declined"
                _ -> "handled"
              end}
            </p>
          <% end %>

          <p class="text-xs text-base-content/50 mt-2">
            {format_timestamp(@notification.inserted_at)}
          </p>
        </div>
        
    <!-- Unread indicator -->
        <%= if !@notification.read do %>
          <div class="flex-shrink-0">
            <button
              type="button"
              id={"notification-mark-read-btn-#{@notification.id}"}
              phx-click="mark_read"
              phx-value-notification-id={@notification.id}
              phx-target={@myself}
              class="btn btn-ghost btn-circle btn-xs"
              title="Mark as read"
            >
              <div class="w-2 h-2 bg-primary rounded-full"></div>
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, !socket.assigns.show_dropdown)}
  end

  @impl true
  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user_id = socket.assigns.current_user.id

    case Notifications.mark_all_as_read(user_id) do
      {:ok, _count} ->
        socket =
          socket
          |> load_notifications()
          |> put_flash(:info, "All notifications marked as read")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to mark notifications as read")}
    end
  end

  @impl true
  def handle_event("mark_read", %{"notification-id" => notification_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Notifications.mark_as_read(notification_id, user_id) do
      {:ok, _notification} ->
        {:noreply, load_notifications(socket)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to mark notification as read")}
    end
  end

  @impl true
  def handle_event("accept_invitation", %{"notification-id" => notification_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Notifications.accept_workspace_invitation(notification_id, user_id) do
      {:ok, _workspace_member} ->
        socket =
          socket
          |> load_notifications()
          |> put_flash(:info, "Workspace invitation accepted!")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Notification not found")}

      {:error, :already_accepted} ->
        {:noreply, put_flash(socket, :error, "Invitation already accepted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to accept invitation")}
    end
  end

  @impl true
  def handle_event("decline_invitation", %{"notification-id" => notification_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Notifications.decline_workspace_invitation(notification_id, user_id) do
      {:ok, _notification} ->
        socket =
          socket
          |> load_notifications()
          |> put_flash(:info, "Workspace invitation declined")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Notification not found")}

      {:error, :already_actioned} ->
        {:noreply, put_flash(socket, :error, "Invitation already handled")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to decline invitation")}
    end
  end

  defp load_notifications(socket) do
    user_id = socket.assigns.current_user.id
    notifications = Notifications.list_notifications(user_id, limit: 20)
    unread_count = Notifications.unread_count(user_id)

    socket
    |> stream(:notifications, notifications, reset: true)
    |> assign(:unread_count, unread_count)
    |> assign(:notifications_loaded, true)
  end

  defp format_timestamp(timestamp) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, timestamp, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> Calendar.strftime(timestamp, "%b %d, %I:%M %p")
    end
  end
end
