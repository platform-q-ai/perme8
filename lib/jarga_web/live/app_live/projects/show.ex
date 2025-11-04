defmodule JargaWeb.AppLive.Projects.Show do
  use JargaWeb, :live_view

  alias Jarga.{Workspaces, Projects}
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <.breadcrumbs>
          <:crumb navigate={~p"/app"}>Home</:crumb>
          <:crumb navigate={~p"/app/workspaces"}>Workspaces</:crumb>
          <:crumb navigate={~p"/app/workspaces/#{@workspace.id}"}>{@workspace.name}</:crumb>
          <:crumb>{@project.name}</:crumb>
        </.breadcrumbs>

        <div class="flex items-center justify-end">
          <div class="flex gap-2">
            <.link
              navigate={~p"/app/workspaces/#{@workspace.id}/projects/#{@project.id}/edit"}
              class="btn btn-ghost"
            >
              <.icon name="hero-pencil" class="size-5" />
              Edit
            </.link>
            <.button
              variant="error"
              phx-click="delete_project"
              data-confirm="Are you sure you want to delete this project?"
            >
              <.icon name="hero-trash" class="size-5" />
              Delete Project
            </.button>
          </div>
        </div>

        <%= if @project.description do %>
          <div class="card bg-base-200">
            <div class="card-body">
              <p>{@project.description}</p>
            </div>
          </div>
        <% end %>

        <div>
          <h2 class="text-lg font-semibold mb-4">Project Details</h2>
          <div class="card bg-base-200">
            <div class="card-body">
              <div class="space-y-2">
                <%= if @project.color do %>
                  <div class="flex items-center gap-2">
                    <span class="text-sm text-base-content/70">Color:</span>
                    <div
                      class="w-8 h-8 rounded"
                      style={"background-color: #{@project.color}"}
                    />
                  </div>
                <% end %>
                <div>
                  <span class="text-sm text-base-content/70">Created:</span>
                  <span class="text-sm ml-2">
                    {Calendar.strftime(@project.inserted_at, "%B %d, %Y")}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(%{"workspace_id" => workspace_id, "id" => project_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    # This will raise if user is not a member
    workspace = Workspaces.get_workspace!(user, workspace_id)
    project = Projects.get_project!(user, workspace_id, project_id)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:project, project)}
  end

  @impl true
  def handle_event("delete_project", _params, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id

    case Projects.delete_project(user, workspace_id, project_id) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted successfully")
         |> push_navigate(to: ~p"/app/workspaces/#{workspace_id}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end
end
