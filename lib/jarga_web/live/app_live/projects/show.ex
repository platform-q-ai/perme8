defmodule JargaWeb.AppLive.Projects.Show do
  use JargaWeb, :live_view

  alias Jarga.{Workspaces, Projects, Pages}
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <.breadcrumbs>
          <:crumb navigate={~p"/app"}>Home</:crumb>
          <:crumb navigate={~p"/app/workspaces"}>Workspaces</:crumb>
          <:crumb navigate={~p"/app/workspaces/#{@workspace.slug}"}>{@workspace.name}</:crumb>
          <:crumb>{@project.name}</:crumb>
        </.breadcrumbs>

        <div class="flex items-center justify-end">
          <div class="flex gap-2">
            <.link
              navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}/edit"}
              class="btn btn-ghost"
            >
              <.icon name="hero-pencil" class="size-5" /> Edit
            </.link>
            <.button
              variant="error"
              phx-click="delete_project"
              data-confirm="Are you sure you want to delete this project?"
            >
              <.icon name="hero-trash" class="size-5" /> Delete Project
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

        <%!-- Pages Section --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Pages</h2>
            <.button variant="primary" size="sm" phx-click="show_page_modal">
              <.icon name="hero-document-plus" class="size-4" />
              New Page
            </.button>
          </div>

          <%= if @pages == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-document" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-lg font-semibold">No pages yet</h3>
                    <p class="text-base-content/70">
                      Create your first page for this project
                    </p>
                  </div>
                  <.button variant="primary" phx-click="show_page_modal">
                    Create Page
                  </.button>
                </div>
              </div>
            </div>
          <% else %>
            <div class="grid gap-2">
              <%= for page <- @pages do %>
                <.link
                  navigate={~p"/app/workspaces/#{@workspace.slug}/pages/#{page.slug}"}
                  class="card bg-base-200 hover:bg-base-300 transition-colors"
                  data-page-id={page.id}
                >
                  <div class="card-body p-4 flex-row items-center gap-3">
                    <.icon name="hero-document-text" class="size-5 text-primary" />
                    <div class="flex-1 min-w-0">
                      <h3 class="font-semibold truncate">{page.title}</h3>
                      <p class="text-xs text-base-content/70">
                        Updated {Calendar.strftime(page.updated_at, "%b %d, %Y at %I:%M %p")}
                      </p>
                    </div>
                    <%= if page.is_pinned do %>
                      <div class="badge badge-warning badge-sm gap-1">
                        <span class="text-xs">📌</span>
                        Pinned
                      </div>
                    <% end %>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>

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

      <%!-- New Page Modal --%>
      <%= if @show_page_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Create New Page</h3>

            <.form
              for={@page_form}
              id="page-form"
              phx-submit="create_page"
              class="space-y-4"
            >
              <.input
                field={@page_form[:title]}
                type="text"
                label="Title"
                placeholder="Page Title"
                required
              />

              <div class="modal-action">
                <.button type="button" variant="ghost" phx-click="hide_page_modal">
                  Cancel
                </.button>
                <.button type="submit" variant="primary">
                  Create Page
                </.button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="hide_page_modal"></div>
        </div>
      <% end %>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(
        %{"workspace_slug" => workspace_slug, "project_slug" => project_slug},
        _session,
        socket
      ) do
    user = socket.assigns.current_scope.user

    # This will raise if user is not a member
    workspace = Workspaces.get_workspace_by_slug!(user, workspace_slug)
    project = Projects.get_project_by_slug!(user, workspace.id, project_slug)
    pages = Pages.list_pages_for_project(user, workspace.id, project.id)

    # Subscribe to workspace-specific PubSub topic for real-time updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
    end

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:project, project)
     |> assign(:pages, pages)
     |> assign(:show_page_modal, false)
     |> assign(:page_form, to_form(%{"title" => ""}))}
  end

  @impl true
  def handle_event("show_page_modal", _params, socket) do
    {:noreply, assign(socket, show_page_modal: true)}
  end

  @impl true
  def handle_event("hide_page_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_page_modal, false)
     |> assign(:page_form, to_form(%{"title" => ""}))}
  end

  @impl true
  def handle_event("create_page", %{"title" => title}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id

    case Pages.create_page(user, workspace_id, %{title: title, project_id: project_id}) do
      {:ok, page} ->
        # Reload pages
        pages = Pages.list_pages_for_project(user, workspace_id, project_id)

        {:noreply,
         socket
         |> assign(:pages, pages)
         |> assign(:show_page_modal, false)
         |> assign(:page_form, to_form(%{"title" => ""}))
         |> put_flash(:info, "Page created successfully")
         |> push_navigate(to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}/pages/#{page.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, page_form: to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create page")}
    end
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
         |> push_navigate(to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
  end

  @impl true
  def handle_info({:page_visibility_changed, _page_id, _is_public}, socket) do
    # Reload pages when a page's visibility changes
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id
    pages = Pages.list_pages_for_project(user, workspace_id, project_id)

    {:noreply, assign(socket, pages: pages)}
  end

  @impl true
  def handle_info({:page_title_changed, page_id, title}, socket) do
    # Update page title in the list
    pages = Enum.map(socket.assigns.pages, fn page ->
      if page.id == page_id do
        %{page | title: title}
      else
        page
      end
    end)

    {:noreply, assign(socket, pages: pages)}
  end

  @impl true
  def handle_info({:workspace_updated, workspace_id, name}, socket) do
    # Update workspace name in breadcrumbs
    if socket.assigns.workspace.id == workspace_id do
      workspace = %{socket.assigns.workspace | name: name}
      {:noreply, assign(socket, workspace: workspace)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:project_updated, project_id, name}, socket) do
    # Update project name in breadcrumbs
    if socket.assigns.project.id == project_id do
      project = %{socket.assigns.project | name: name}
      {:noreply, assign(socket, project: project)}
    else
      {:noreply, socket}
    end
  end
end
