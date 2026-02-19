defmodule JargaWeb.AppLive.Workspaces.Index do
  @moduledoc """
  LiveView for listing all workspaces.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.Workspaces
  alias JargaWeb.Layouts

  # Cross-context domain events
  alias Identity.Domain.Events.{WorkspaceUpdated, MemberRemoved, WorkspaceInvitationNotified}
  alias Jarga.Notifications.Domain.Events.NotificationActionTaken

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <:breadcrumbs navigate={~p"/app"}>Home</:breadcrumbs>
      <:breadcrumbs>Workspaces</:breadcrumbs>

      <div class="space-y-8">
        <.header>
          Workspaces
          <:subtitle>Manage your workspaces and collaborate with your team</:subtitle>
          <:actions>
            <.button variant="primary" size="sm" navigate={~p"/app/workspaces/new"}>
              <.icon name="hero-plus" class="size-4" /> New Workspace
            </.button>
          </:actions>
        </.header>

        <%= if @workspaces == [] do %>
          <div class="card bg-base-200">
            <div class="card-body text-center">
              <div class="flex flex-col items-center gap-4 py-8">
                <.icon name="hero-briefcase" class="size-16 opacity-50" />
                <div>
                  <h3 class="text-base font-semibold">No workspaces yet</h3>
                  <p class="text-base-content/70">
                    Create your first workspace to get started
                  </p>
                </div>
                <.link navigate={~p"/app/workspaces/new"} class="btn btn-primary">
                  Create Workspace
                </.link>
              </div>
            </div>
          </div>
        <% else %>
          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <%= for workspace <- @workspaces do %>
              <.link
                navigate={~p"/app/workspaces/#{workspace.slug}"}
                class="card bg-base-200 hover:bg-base-300 transition-colors"
                data-workspace-id={workspace.id}
              >
                <div class="card-body">
                  <%= if workspace.color do %>
                    <div
                      class="w-12 h-1 rounded mb-2"
                      style={"background-color: #{workspace.color}"}
                    />
                  <% end %>
                  <h2 class="card-title">
                    <.icon name="hero-briefcase" class="size-5 text-primary" />
                    {workspace.name}
                  </h2>
                  <%= if workspace.description do %>
                    <p class="text-sm text-base-content/70">{workspace.description}</p>
                  <% end %>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)

    # Subscribe to structured domain events
    if connected?(socket) do
      Perme8.Events.subscribe("events:user:#{user.id}")

      # Subscribe to each workspace for name updates
      Enum.each(workspaces, fn workspace ->
        Perme8.Events.subscribe("events:workspace:#{workspace.id}")
      end)
    end

    {:ok, assign(socket, workspaces: workspaces)}
  end

  # --- Workspace invitation events (from user topic) ---

  @impl true
  def handle_info(%WorkspaceInvitationNotified{workspace_id: workspace_id}, socket) do
    # Reload workspaces when user is invited to a new workspace
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)

    # Subscribe to the new workspace's event topic
    Perme8.Events.subscribe("events:workspace:#{workspace_id}")

    {:noreply, assign(socket, workspaces: workspaces)}
  end

  @impl true
  def handle_info(%NotificationActionTaken{action: "accepted", user_id: uid} = _event, socket) do
    current_user_id = socket.assigns.current_scope.user.id

    if uid == current_user_id do
      # "I joined a workspace" (received via user topic) — reload workspaces + subscribe
      user = socket.assigns.current_scope.user
      workspaces = Workspaces.list_workspaces_for_user(user)

      # Find newly joined workspace and subscribe to its events
      current_ws_ids =
        Enum.map(socket.assigns.workspaces, & &1.id) |> MapSet.new()

      Enum.each(workspaces, fn ws ->
        unless MapSet.member?(current_ws_ids, ws.id) do
          Perme8.Events.subscribe("events:workspace:#{ws.id}")
        end
      end)

      {:noreply, assign(socket, workspaces: workspaces)}
    else
      # "Someone joined my workspace" (received via workspace topic) — no-op on index
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%MemberRemoved{target_user_id: target_user_id}, socket) do
    if target_user_id == socket.assigns.current_scope.user.id do
      # Current user was removed from a workspace — reload workspaces
      user = socket.assigns.current_scope.user
      workspaces = Workspaces.list_workspaces_for_user(user)
      {:noreply, assign(socket, workspaces: workspaces)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%WorkspaceUpdated{workspace_id: workspace_id, name: name}, socket) do
    # Update workspace name in the list
    workspaces =
      Enum.map(socket.assigns.workspaces, fn workspace ->
        if workspace.id == workspace_id do
          %{workspace | name: name}
        else
          workspace
        end
      end)

    {:noreply, assign(socket, workspaces: workspaces)}
  end

  # Chat panel streaming messages and notification handlers
  handle_chat_messages()
end
