defmodule JargaWeb.AppLive.Projects.Show do
  @moduledoc """
  LiveView for displaying project details with associated pages.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers
  import JargaWeb.Live.PermissionsHelper

  alias Jarga.{Workspaces, Projects, Documents}
  alias JargaWeb.Layouts

  # Document domain events
  alias Jarga.Documents.Domain.Events.{
    DocumentVisibilityChanged,
    DocumentTitleChanged,
    DocumentPinnedChanged,
    DocumentCreated,
    DocumentDeleted
  }

  # Cross-context domain events
  alias Identity.Domain.Events.WorkspaceUpdated
  alias Jarga.Projects.Domain.Events.{ProjectUpdated, ProjectDeleted}

  # Agent domain events
  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_scope={@current_scope}
      workspace={@workspace}
      project={@project}
    >
      <div class="space-y-8">
        <%= if can_edit_project?(@current_member, @project, @current_scope.user) || can_delete_project?(@current_member, @project, @current_scope.user) do %>
          <div class="flex items-center justify-end">
            <.kebab_menu>
              <:item
                :if={can_edit_project?(@current_member, @project, @current_scope.user)}
                icon="hero-pencil"
                navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}/edit"}
              >
                Edit Project
              </:item>
              <:item
                :if={can_delete_project?(@current_member, @project, @current_scope.user)}
                icon="hero-trash"
                variant="error"
                phx_click="delete_project"
                data_confirm="Are you sure you want to delete this project?"
              >
                Delete Project
              </:item>
            </.kebab_menu>
          </div>
        <% end %>

        <%= if @project.description do %>
          <div class="card bg-base-200">
            <div class="card-body">
              <p>{@project.description}</p>
            </div>
          </div>
        <% end %>

        <%!-- Documents Section --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Documents</h2>
            <.button variant="primary" size="sm" phx-click="show_document_modal">
              <.icon name="hero-plus" class="size-4" /> New Document
            </.button>
          </div>

          <%= if @documents == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-document" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-base font-semibold">No documents yet</h3>
                    <p class="text-base-content/70">
                      Create your first document for this project
                    </p>
                  </div>
                  <.button variant="primary" phx-click="show_document_modal">
                    Create Document
                  </.button>
                </div>
              </div>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th class="text-sm font-semibold">Title</th>
                    <th class="text-sm font-semibold">Last Updated</th>
                    <th class="text-sm font-semibold text-right">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for document <- @documents do %>
                    <tr data-document-id={document.id} data-pinned={to_string(document.is_pinned)}>
                      <td>
                        <.link
                          navigate={~p"/app/workspaces/#{@workspace.slug}/documents/#{document.slug}"}
                          class="text-sm font-medium hover:text-primary transition-colors flex items-center gap-2"
                        >
                          <.icon name="hero-document-text" class="size-4" />
                          {document.title}
                        </.link>
                      </td>
                      <td class="text-sm">
                        {Calendar.strftime(document.updated_at, "%b %d, %Y at %I:%M %p")}
                      </td>
                      <td class="text-sm text-right">
                        <%= if document.is_pinned do %>
                          <span class="badge badge-sm badge-warning gap-1">
                            <.icon name="lucide-pin" class="size-3" /> Pinned
                          </span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
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

      <%!-- New Document Modal --%>
      <%= if @show_document_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="text-lg font-bold mb-4">Create New Document</h3>

            <.form
              for={@document_form}
              id="document-form"
              phx-change="validate_document"
              phx-submit="create_document"
              class="space-y-4"
            >
              <.input
                field={@document_form[:title]}
                type="text"
                label="Title"
                placeholder="Document Title"
              />

              <div class="modal-action">
                <.button type="button" variant="ghost" phx-click="hide_document_modal">
                  Cancel
                </.button>
                <.button type="submit" variant="primary">
                  Create Document
                </.button>
              </div>
            </.form>
          </div>
          <form method="dialog" class="modal-backdrop" phx-click="hide_document_modal">
            <button>close</button>
          </form>
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

    with {:ok, workspace, current_member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug),
         {:ok, project} <- get_project_by_slug(user, workspace.id, project_slug) do
      documents = Documents.list_documents_for_project(user, workspace.id, project.id)

      # Subscribe to workspace-scoped structured domain events
      if connected?(socket) do
        Perme8.Events.subscribe("events:workspace:#{workspace.id}")
      end

      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:current_member, current_member)
       |> assign(:project, project)
       |> assign(:documents, documents)
       |> assign(:show_document_modal, false)
       |> assign(:document_form, to_form(%{"title" => ""}, as: "document-form"))}
    else
      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> redirect(to: ~p"/app/workspaces")}
    end
  end

  @impl true
  def handle_event("validate_document", %{"document-form" => params}, socket) do
    errors =
      if String.trim(params["title"] || "") == "" do
        [title: {"can't be blank", [validation: :required]}]
      else
        []
      end

    form = to_form(params, as: "document-form", errors: errors)
    {:noreply, assign(socket, :document_form, form)}
  end

  @impl true
  def handle_event("show_document_modal", _params, socket) do
    {:noreply, assign(socket, show_document_modal: true)}
  end

  @impl true
  def handle_event("hide_document_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_document_modal, false)
     |> assign(:document_form, to_form(%{"title" => ""}, as: "document-form"))}
  end

  @impl true
  def handle_event("create_document", %{"document-form" => %{"title" => title}}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id

    case Documents.create_document(user, workspace_id, %{title: title, project_id: project_id}) do
      {:ok, document} ->
        # Reload documents
        documents = Documents.list_documents_for_project(user, workspace_id, project_id)

        {:noreply,
         socket
         |> assign(:documents, documents)
         |> assign(:show_document_modal, false)
         |> assign(:document_form, to_form(%{"title" => ""}, as: "document-form"))
         |> put_flash(:info, "Document created successfully")
         |> push_navigate(
           to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}/documents/#{document.slug}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, document_form: to_form(changeset, as: "document-form"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create document")}
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

  # Document domain events

  @impl true
  def handle_info(%DocumentVisibilityChanged{}, socket) do
    # Reload documents when a document's visibility changes
    {:noreply, reload_documents(socket)}
  end

  @impl true
  def handle_info(%DocumentTitleChanged{document_id: document_id, title: title}, socket) do
    # Update document title in the list
    documents =
      Enum.map(socket.assigns.documents, fn document ->
        if document.id == document_id do
          %{document | title: title}
        else
          document
        end
      end)

    {:noreply, assign(socket, documents: documents)}
  end

  @impl true
  def handle_info(%DocumentPinnedChanged{document_id: document_id, is_pinned: is_pinned}, socket) do
    # Update document pinned status in the list
    documents =
      Enum.map(socket.assigns.documents, fn document ->
        if document.id == document_id do
          %{document | is_pinned: is_pinned}
        else
          document
        end
      end)

    {:noreply, assign(socket, documents: documents)}
  end

  @impl true
  def handle_info(%DocumentCreated{project_id: project_id}, socket) do
    # Add new document to the list if it belongs to this project
    if project_id == socket.assigns.project.id do
      {:noreply, reload_documents(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%DocumentDeleted{document_id: document_id}, socket) do
    # Remove document from the list
    documents = Enum.reject(socket.assigns.documents, fn doc -> doc.id == document_id end)
    {:noreply, assign(socket, documents: documents)}
  end

  # Workspace and project domain events

  @impl true
  def handle_info(%WorkspaceUpdated{workspace_id: workspace_id, name: name}, socket) do
    # Update workspace name in breadcrumbs
    if socket.assigns.workspace.id == workspace_id do
      workspace = %{socket.assigns.workspace | name: name}
      {:noreply, assign(socket, workspace: workspace)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%ProjectUpdated{project_id: project_id, name: name}, socket) do
    # Update project name in breadcrumbs
    if socket.assigns.project.id == project_id do
      project = %{socket.assigns.project | name: name}
      {:noreply, assign(socket, project: project)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%ProjectDeleted{project_id: project_id}, socket) do
    # If the current project was deleted, redirect to workspace page
    if socket.assigns.project.id == project_id do
      {:noreply,
       socket
       |> put_flash(:info, "Project was deleted")
       |> push_navigate(to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}")}
    else
      {:noreply, socket}
    end
  end

  # Agent domain events — reload workspace agents and update chat panel

  @impl true
  def handle_info(%AgentUpdated{}, socket), do: {:noreply, reload_workspace_agents(socket)}

  @impl true
  def handle_info(%AgentDeleted{}, socket), do: {:noreply, reload_workspace_agents(socket)}

  @impl true
  def handle_info(%AgentAddedToWorkspace{}, socket),
    do: {:noreply, reload_workspace_agents(socket)}

  @impl true
  def handle_info(%AgentRemovedFromWorkspace{}, socket),
    do: {:noreply, reload_workspace_agents(socket)}

  defp get_project_by_slug(user, workspace_id, slug) do
    Projects.get_project_by_slug(user, workspace_id, slug)
  end

  defp reload_documents(socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id
    documents = Documents.list_documents_for_project(user, workspace_id, project_id)
    assign(socket, documents: documents)
  end

  defp reload_workspace_agents(socket) do
    workspace_id = socket.assigns.workspace.id
    user = socket.assigns.current_scope.user
    agents = Agents.get_workspace_agents_list(workspace_id, user.id, enabled_only: true)

    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      workspace_agents: agents,
      from_pubsub: true
    )

    socket
  end

  # Chat panel streaming messages
  handle_chat_messages()
end
