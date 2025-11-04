defmodule JargaWeb.AppLive.Workspaces.Show do
  use JargaWeb, :live_view

  alias Jarga.{Workspaces, Projects}
  alias Jarga.Projects.Project
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <.breadcrumbs>
          <:crumb navigate={~p"/app"}>Home</:crumb>
          <:crumb navigate={~p"/app/workspaces"}>Workspaces</:crumb>
          <:crumb>{@workspace.name}</:crumb>
        </.breadcrumbs>

        <div class="flex items-center justify-between">
          <.header>
            {@workspace.name}
            <:subtitle>
              <.link navigate={~p"/app/workspaces"} class="text-sm hover:underline">
                ← Back to Workspaces
              </.link>
            </:subtitle>
          </.header>
          <div class="flex gap-2">
            <.link navigate={~p"/app/workspaces/#{@workspace.id}/edit"} class="btn btn-ghost">
              <.icon name="hero-pencil" class="size-5" />
              Edit
            </.link>
            <.button variant="error" phx-click="delete_workspace" data-confirm="Are you sure you want to delete this workspace? All projects will also be deleted.">
              <.icon name="hero-trash" class="size-5" />
              Delete Workspace
            </.button>
            <.button variant="primary" phx-click="show_project_modal">
              New Project
            </.button>
          </div>
        </div>

        <%= if @workspace.description do %>
          <div class="card bg-base-200">
            <div class="card-body">
              <p>{@workspace.description}</p>
            </div>
          </div>
        <% end %>

        <div>
          <h2 class="text-lg font-semibold mb-4">Projects</h2>

          <%= if @projects == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-folder" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-lg font-semibold">No projects yet</h3>
                    <p class="text-base-content/70">
                      Create your first project to get started
                    </p>
                  </div>
                  <.button variant="primary" phx-click="show_project_modal">
                    Create Project
                  </.button>
                </div>
              </div>
            </div>
          <% else %>
            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <%= for project <- @projects do %>
                <.link
                  navigate={~p"/app/workspaces/#{@workspace.id}/projects/#{project.id}"}
                  class="card bg-base-200 hover:bg-base-300 transition-colors"
                  data-project-id={project.id}
                >
                  <div class="card-body">
                    <%= if project.color do %>
                      <div
                        class="w-12 h-1 rounded mb-2"
                        style={"background-color: #{project.color}"}
                      />
                    <% end %>
                    <h3 class="card-title">{project.name}</h3>
                    <%= if project.description do %>
                      <p class="text-sm text-base-content/70">{project.description}</p>
                    <% end %>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- New Project Modal --%>
      <%= if @show_project_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Create New Project</h3>

            <.form
              for={@project_form}
              id="project-form"
              phx-submit="create_project"
              class="space-y-4"
            >
              <.input
                field={@project_form[:name]}
                type="text"
                label="Name"
                placeholder="My Project"
                required
              />

              <.input
                field={@project_form[:description]}
                type="textarea"
                label="Description"
                placeholder="Describe your project..."
              />

              <.input
                field={@project_form[:color]}
                type="text"
                label="Color"
                placeholder="#10B981"
              />

              <div class="modal-action">
                <.button type="button" variant="ghost" phx-click="hide_project_modal">
                  Cancel
                </.button>
                <.button type="submit" variant="primary">
                  Create Project
                </.button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="hide_project_modal"></div>
        </div>
      <% end %>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(%{"id" => workspace_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    # This will raise if user is not a member
    workspace = Workspaces.get_workspace!(user, workspace_id)
    projects = Projects.list_projects_for_workspace(user, workspace_id)

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:projects, projects)
     |> assign(:show_project_modal, false)
     |> assign(:project_form, to_form(Project.changeset(%Project{}, %{})))}
  end

  @impl true
  def handle_event("show_project_modal", _params, socket) do
    {:noreply, assign(socket, show_project_modal: true)}
  end

  @impl true
  def handle_event("hide_project_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_project_modal, false)
     |> assign(:project_form, to_form(Project.changeset(%Project{}, %{})))}
  end

  @impl true
  def handle_event("create_project", %{"project" => project_params}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id

    case Projects.create_project(user, workspace_id, project_params) do
      {:ok, _project} ->
        # Reload projects
        projects = Projects.list_projects_for_workspace(user, workspace_id)

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:show_project_modal, false)
         |> assign(:project_form, to_form(Project.changeset(%Project{}, %{})))
         |> put_flash(:info, "Project created successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, project_form: to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create project")}
    end
  end

  @impl true
  def handle_event("delete_workspace", _params, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id

    case Workspaces.delete_workspace(user, workspace_id) do
      {:ok, _workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace deleted successfully")
         |> push_navigate(to: ~p"/app/workspaces")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete workspace")}
    end
  end
end
