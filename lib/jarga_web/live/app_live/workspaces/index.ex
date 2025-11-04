defmodule JargaWeb.AppLive.Workspaces.Index do
  use JargaWeb, :live_view

  alias Jarga.Workspaces
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <.breadcrumbs>
          <:crumb navigate={~p"/app"}>Home</:crumb>
          <:crumb>Workspaces</:crumb>
        </.breadcrumbs>

        <div class="flex items-center justify-between">
          <.header>
            Workspaces
            <:subtitle>Manage your workspaces and collaborate with your team</:subtitle>
          </.header>
          <.link navigate={~p"/app/workspaces/new"} class="btn btn-primary">
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
                navigate={~p"/app/workspaces/#{workspace.id}"}
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
    </Layouts.admin>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)

    {:ok, assign(socket, workspaces: workspaces)}
  end
end
