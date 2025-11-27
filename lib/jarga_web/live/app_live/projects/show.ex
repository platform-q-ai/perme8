defmodule JargaWeb.AppLive.Projects.Show do
  @moduledoc """
  LiveView for displaying project details with associated pages.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.{Workspaces, Projects, Documents}
  alias JargaWeb.Layouts

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
        <div class="flex items-center justify-end">
          <.kebab_menu>
            <:item
              icon="hero-pencil"
              navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}/edit"}
            >
              Edit Project
            </:item>
            <:item
              icon="hero-trash"
              variant="error"
              phx_click="delete_project"
              data_confirm="Are you sure you want to delete this project?"
            >
              Delete Project
            </:item>
          </.kebab_menu>
        </div>

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
              phx-submit="create_document"
              class="space-y-4"
            >
              <.input
                field={@document_form[:title]}
                type="text"
                label="Title"
                placeholder="Document Title"
                required
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

    with {:ok, workspace} <- Workspaces.get_workspace_by_slug(user, workspace_slug),
         {:ok, project} <- get_project_by_slug(user, workspace.id, project_slug) do
      documents = Documents.list_documents_for_project(user, workspace.id, project.id)

      # Subscribe to workspace-specific PubSub topic for real-time updates
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
      end

      {:ok,
       socket
       |> assign(:workspace, workspace)
       |> assign(:project, project)
       |> assign(:documents, documents)
       |> assign(:show_document_modal, false)
       |> assign(:document_form, to_form(%{"title" => ""}))}
    else
      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> redirect(to: ~p"/app/workspaces")}
    end
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
     |> assign(:document_form, to_form(%{"title" => ""}))}
  end

  @impl true
  def handle_event("create_document", %{"title" => title}, socket) do
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
         |> assign(:document_form, to_form(%{"title" => ""}))
         |> put_flash(:info, "Document created successfully")
         |> push_navigate(
           to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}/documents/#{document.slug}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, document_form: to_form(changeset))}

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

  @impl true
  def handle_info({:document_visibility_changed, _document_id, _is_public}, socket) do
    # Reload documents when a document's visibility changes
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id
    documents = Documents.list_documents_for_project(user, workspace_id, project_id)

    {:noreply, assign(socket, documents: documents)}
  end

  @impl true
  def handle_info({:document_title_changed, document_id, title}, socket) do
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
  def handle_info({:document_pinned_changed, document_id, is_pinned}, socket) do
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
  def handle_info({:document_created, document}, socket) do
    # Add new document to the list if it belongs to this project
    if document.project_id == socket.assigns.project.id do
      documents = [document | socket.assigns.documents]
      {:noreply, assign(socket, documents: documents)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:document_deleted, document_id}, socket) do
    # Remove document from the list
    documents = Enum.reject(socket.assigns.documents, fn doc -> doc.id == document_id end)
    {:noreply, assign(socket, documents: documents)}
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

  @impl true
  def handle_info({:project_removed, project_id}, socket) do
    # If the current project was removed, redirect to workspace page
    if socket.assigns.project.id == project_id do
      {:noreply,
       socket
       |> put_flash(:info, "Project was deleted")
       |> push_navigate(to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:workspace_agent_updated, _agent}, socket) do
    # Reload workspace agents and send to chat panel
    workspace_id = socket.assigns.workspace.id
    user = socket.assigns.current_scope.user

    agents = Jarga.Agents.get_workspace_agents_list(workspace_id, user.id, enabled_only: true)

    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      workspace_agents: agents,
      from_pubsub: true
    )

    {:noreply, socket}
  end

  defp get_project_by_slug(user, workspace_id, slug) do
    Projects.get_project_by_slug(user, workspace_id, slug)
  end

  # Chat panel streaming messages
  handle_chat_messages()
end
