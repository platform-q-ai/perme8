defmodule JargaWeb.AppLive.Dashboard do
  use JargaWeb, :live_view

  alias Jarga.Workspaces
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div>
          <.header>
            Welcome to Jarga
            <:subtitle>Your authenticated dashboard</:subtitle>
          </.header>
        </div>

        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Your Workspaces</h3>
            <.link navigate={~p"/app/workspaces/new"} class="btn btn-primary btn-sm">
              New Workspace
            </.link>
          </div>

          <%= if @workspaces == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-rectangle-group" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-lg font-semibold">No workspaces yet</h3>
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
                    <h2 class="card-title">{workspace.name}</h2>
                    <%= if workspace.description do %>
                      <p class="text-sm text-base-content/70">{workspace.description}</p>
                    <% end %>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)

    # Subscribe to user-specific PubSub topic for real-time updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jarga.PubSub, "user:#{user.id}")

      # Subscribe to each workspace for name updates
      Enum.each(workspaces, fn workspace ->
        Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
      end)
    end

    {:ok, assign(socket, workspaces: workspaces)}
  end

  @impl true
  def handle_info({:workspace_invitation, workspace_id, _workspace_name, _inviter_name}, socket) do
    # Reload workspaces when user is added to a workspace
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)

    # Subscribe to the new workspace
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace_id}")

    {:noreply, assign(socket, workspaces: workspaces)}
  end

  @impl true
  def handle_info({:workspace_removed, _workspace_id}, socket) do
    # Reload workspaces when user is removed from a workspace
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)

    {:noreply, assign(socket, workspaces: workspaces)}
  end

  @impl true
  def handle_info({:workspace_updated, workspace_id, name}, socket) do
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

  @impl true
  def handle_info({:page_visibility_changed, _page_id, _is_public}, socket) do
    # Page visibility changed - not relevant to dashboard view
    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_pinned_changed, _page_id, _is_pinned}, socket) do
    # Page pinned state changed - not relevant to dashboard view
    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_title_changed, _page_id, _title}, socket) do
    # Page title changed - not relevant to dashboard view
    {:noreply, socket}
  end
end
