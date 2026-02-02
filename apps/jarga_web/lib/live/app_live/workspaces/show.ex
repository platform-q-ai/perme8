defmodule JargaWeb.AppLive.Workspaces.Show do
  @moduledoc """
  LiveView for displaying workspace details with projects and pages.
  """

  use JargaWeb, :live_view

  import JargaWeb.Live.PermissionsHelper
  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.{Workspaces, Projects, Documents, Agents}
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope} workspace={@workspace}>
      <div class="space-y-8">
        <%= if can_edit_workspace?(@current_member) || can_manage_members?(@current_member) || can_delete_workspace?(@current_member) do %>
          <div class="flex items-center justify-end">
            <.kebab_menu>
              <:item
                :if={can_edit_workspace?(@current_member)}
                icon="hero-pencil"
                navigate={~p"/app/workspaces/#{@workspace.slug}/edit"}
              >
                Edit Workspace
              </:item>
              <:item
                :if={can_manage_members?(@current_member)}
                icon="hero-user-group"
                phx_click="show_members_modal"
              >
                Manage Members
              </:item>
              <:item
                :if={can_delete_workspace?(@current_member)}
                icon="hero-trash"
                variant="error"
                phx_click="delete_workspace"
                data_confirm="Are you sure you want to delete this workspace? All projects will also be deleted."
              >
                Delete Workspace
              </:item>
            </.kebab_menu>
          </div>
        <% end %>

        <%= if @workspace.description do %>
          <div class="card bg-base-200">
            <div class="card-body">
              <p>{@workspace.description}</p>
            </div>
          </div>
        <% end %>

        <%!-- Projects Section --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Projects</h2>
            <%= if can_create_project?(@current_member) do %>
              <.button variant="primary" size="sm" phx-click="show_project_modal">
                <.icon name="hero-plus" class="size-4" /> New Project
              </.button>
            <% end %>
          </div>

          <%= if @projects == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-folder" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-base font-semibold">No projects yet</h3>
                    <p class="text-base-content/70">
                      <%= if can_create_project?(@current_member) do %>
                        Create your first project to get started
                      <% else %>
                        No projects have been created yet
                      <% end %>
                    </p>
                  </div>
                  <%= if can_create_project?(@current_member) do %>
                    <.button variant="primary" phx-click="show_project_modal">
                      Create Project
                    </.button>
                  <% end %>
                </div>
              </div>
            </div>
          <% else %>
            <div class="grid gap-2">
              <%= for project <- @projects do %>
                <.link
                  navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{project.slug}"}
                  class="card bg-base-200 hover:bg-base-300 transition-colors"
                  data-project-id={project.id}
                >
                  <div class="card-body p-4 flex-row items-center gap-3">
                    <.icon name="hero-folder" class="size-5 text-primary" />
                    <div class="flex-1 min-w-0">
                      <%= if project.color do %>
                        <div
                          class="w-12 h-1 rounded mb-1"
                          style={"background-color: #{project.color}"}
                        />
                      <% end %>
                      <h3 class="text-sm font-semibold truncate">{project.name}</h3>
                      <%= if project.description do %>
                        <p class="text-xs text-base-content/70 truncate">{project.description}</p>
                      <% end %>
                    </div>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Documents Section --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Documents</h2>
            <%= if can_create_document?(@current_member) do %>
              <.button variant="primary" size="sm" phx-click="show_document_modal">
                <.icon name="hero-plus" class="size-4" /> New Document
              </.button>
            <% end %>
          </div>

          <%= if @documents == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-document" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-base font-semibold">No documents yet</h3>
                    <p class="text-base-content/70">
                      <%= if can_create_document?(@current_member) do %>
                        Create your first document to start documenting
                      <% else %>
                        No documents have been created yet
                      <% end %>
                    </p>
                  </div>
                  <%= if can_create_document?(@current_member) do %>
                    <.button variant="primary" phx-click="show_document_modal">
                      Create Document
                    </.button>
                  <% end %>
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
                    <tr data-document-id={document.id}>
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

        <%!-- Agents Section --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Agents</h2>
            <.button
              variant="primary"
              size="sm"
              navigate={~p"/app/agents/new"}
            >
              <.icon name="hero-plus" class="size-4" /> New Agent
            </.button>
          </div>

          <%= if @my_agents == [] && @other_agents == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-cpu-chip" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-base font-semibold">No agents in this workspace yet</h3>
                    <p class="text-base-content/70">
                      Add your agents to this workspace to collaborate
                    </p>
                  </div>
                  <.button variant="primary" navigate={~p"/app/agents/new"}>
                    Create Agent
                  </.button>
                </div>
              </div>
            </div>
          <% else %>
            <%!-- My Agents Section --%>
            <%= if @my_agents != [] do %>
              <div class="mb-6">
                <h3 class="text-base font-semibold mb-3">My Agents</h3>
                <div class="overflow-x-auto">
                  <table class="table table-zebra">
                    <thead>
                      <tr>
                        <th class="text-sm font-semibold">Name</th>
                        <th class="text-sm font-semibold">Model</th>
                        <th class="text-sm font-semibold text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for agent <- @my_agents do %>
                        <tr data-agent-id={agent.id}>
                          <td class="text-sm font-medium">{agent.name}</td>
                          <td class="text-sm">{agent.model || "Not set"}</td>
                          <td class="text-sm text-right">
                            <div class="flex justify-end gap-1">
                              <.link
                                navigate={
                                  ~p"/app/agents/#{agent.id}/edit?return_to=workspace&workspace_slug=#{@workspace.slug}"
                                }
                                class="btn btn-sm btn-ghost"
                                title="Edit agent"
                              >
                                <.icon name="hero-pencil" class="size-4" />
                              </.link>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>

            <%!-- Shared Agents Section --%>
            <%= if @other_agents != [] do %>
              <div>
                <h3 class="text-base font-semibold mb-3">Shared by Others</h3>
                <div class="overflow-x-auto">
                  <table class="table table-zebra">
                    <thead>
                      <tr>
                        <th class="text-sm font-semibold">Name</th>
                        <th class="text-sm font-semibold">Model</th>
                        <th class="text-sm font-semibold text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for agent <- @other_agents do %>
                        <tr data-agent-id={agent.id}>
                          <td class="text-sm font-medium">{agent.name}</td>
                          <td class="text-sm">{agent.model || "Not set"}</td>
                          <td class="text-sm text-right">
                            <div class="flex justify-end gap-1">
                              <.link
                                navigate={
                                  ~p"/app/agents/#{agent.id}/view?return_to=workspace&workspace_slug=#{@workspace.slug}"
                                }
                                class="btn btn-sm btn-ghost"
                                title="View agent details"
                              >
                                <.icon name="hero-eye" class="size-4" />
                              </.link>
                              <button
                                phx-click="clone_agent"
                                phx-value-agent-id={agent.id}
                                class="btn btn-sm btn-primary"
                                title="Clone to my agents"
                              >
                                <.icon name="hero-document-duplicate" class="size-4" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Members Management Modal --%>
      <%= if @show_members_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-4xl max-h-[90vh] flex flex-col p-0">
            <%!-- Modal Header --%>
            <div class="sticky top-0 bg-base-100 border-b border-base-300 px-6 py-4 z-10">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-bold">Manage Members</h3>
                <button
                  phx-click="hide_members_modal"
                  class="btn btn-sm btn-circle btn-ghost"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>
            </div>

            <%!-- Modal Body --%>
            <div class="flex-1 overflow-y-auto px-6 py-6 space-y-6">
              <%!-- Invite Section --%>
              <div class="card bg-base-200">
                <div class="card-body p-4">
                  <h4 class="text-sm font-semibold mb-3 flex items-center gap-2">
                    <.icon name="hero-envelope" class="size-5 text-primary" /> Invite New Member
                  </h4>
                  <.form
                    for={@invite_form}
                    id="invite-form"
                    phx-submit="invite_member"
                    class="flex flex-col sm:flex-row gap-2"
                  >
                    <div class="flex-1">
                      <.input
                        field={@invite_form[:email]}
                        type="email"
                        label="Email"
                        placeholder="user@example.com"
                        required
                      />
                    </div>

                    <div class="w-full sm:w-40">
                      <.input
                        field={@invite_form[:role]}
                        type="select"
                        label="Role"
                        options={[
                          {"Admin", "admin"},
                          {"Member", "member"},
                          {"Guest", "guest"}
                        ]}
                        required
                      />
                    </div>

                    <div class="fieldset mb-2 w-full sm:w-auto">
                      <label>
                        <span class="label mb-1">&nbsp;</span>
                        <.button type="submit" variant="primary" class="w-full">
                          <.icon name="hero-user-plus" class="size-4" /> Invite
                        </.button>
                      </label>
                    </div>
                  </.form>
                </div>
              </div>

              <%!-- Members List --%>
              <div>
                <div class="flex items-center justify-between mb-4">
                  <h4 class="text-sm font-semibold flex items-center gap-2">
                    <.icon name="hero-user-group" class="size-5 text-primary" /> Team Members
                  </h4>
                  <span class="badge badge-neutral badge-sm">
                    {length(@members)} {if length(@members) == 1, do: "member", else: "members"}
                  </span>
                </div>

                <%= if @members == [] do %>
                  <div class="card bg-base-200">
                    <div class="card-body text-center py-8">
                      <.icon name="hero-users" class="size-12 mx-auto opacity-50 mb-2" />
                      <p class="text-base-content/70">No members yet</p>
                    </div>
                  </div>
                <% else %>
                  <div class="overflow-x-auto rounded-lg border border-base-300">
                    <table class="table table-sm">
                      <thead class="bg-base-200">
                        <tr>
                          <th class="text-sm font-semibold">Member</th>
                          <th class="text-sm font-semibold">Role</th>
                          <th class="text-sm font-semibold">Status</th>
                          <th class="text-sm font-semibold">Joined</th>
                          <th class="text-sm font-semibold text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody id="members-list">
                        <%= for member <- @members do %>
                          <tr class="hover" id={"member-#{member.id}"}>
                            <td>
                              <div class="flex items-center gap-2">
                                <div class="avatar placeholder">
                                  <div class="bg-neutral text-neutral-content w-8 rounded-full">
                                    <span class="text-xs">
                                      {member.email |> String.slice(0..1) |> String.upcase()}
                                    </span>
                                  </div>
                                </div>
                                <span class="text-sm font-medium">{member.email}</span>
                              </div>
                            </td>
                            <td>
                              <%= if member.role == :owner do %>
                                <div class="badge badge-primary badge-sm gap-1">
                                  <.icon name="hero-star-solid" class="size-3" /> Owner
                                </div>
                              <% else %>
                                <select
                                  class="select select-xs select-bordered"
                                  phx-change="change_role"
                                  phx-value-email={member.email}
                                >
                                  <option value="admin" selected={member.role == :admin}>
                                    Admin
                                  </option>
                                  <option value="member" selected={member.role == :member}>
                                    Member
                                  </option>
                                  <option value="guest" selected={member.role == :guest}>
                                    Guest
                                  </option>
                                </select>
                              <% end %>
                            </td>
                            <td>
                              <%= if member.joined_at do %>
                                <div class="badge badge-success badge-sm gap-1">
                                  <div class="w-1.5 h-1.5 rounded-full bg-success-content"></div>
                                  Active
                                </div>
                              <% else %>
                                <div class="badge badge-warning badge-sm gap-1">
                                  <.icon name="hero-clock" class="size-3" /> Pending
                                </div>
                              <% end %>
                            </td>
                            <td class="text-sm">
                              <%= if member.joined_at do %>
                                {Calendar.strftime(member.joined_at, "%b %d, %Y")}
                              <% else %>
                                <span class="text-base-content/50 italic">Not yet</span>
                              <% end %>
                            </td>
                            <td class="text-sm text-right">
                              <%= if member.role != :owner do %>
                                <.button
                                  variant="ghost"
                                  size="xs"
                                  phx-click="remove_member"
                                  phx-value-email={member.email}
                                  data-confirm="Are you sure you want to remove this member?"
                                  class="text-error hover:bg-error hover:text-error-content"
                                >
                                  <.icon name="hero-trash" class="size-4" />
                                </.button>
                              <% else %>
                                <span class="text-base-content/30 text-xs">—</span>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Modal Footer --%>
            <div class="sticky bottom-0 bg-base-100 border-t border-base-300 px-6 py-4">
              <div class="flex justify-end">
                <.button variant="neutral" phx-click="hide_members_modal">
                  Done
                </.button>
              </div>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop" phx-click="hide_members_modal">
            <button>close</button>
          </form>
        </div>
      <% end %>

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

      <%!-- New Project Modal --%>
      <%= if @show_project_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="text-lg font-bold mb-4">Create New Project</h3>

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
          <form method="dialog" class="modal-backdrop" phx-click="hide_project_modal">
            <button>close</button>
          </form>
        </div>
      <% end %>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(%{"slug" => workspace_slug}, _session, socket) do
    user = socket.assigns.current_scope.user

    # Optimized: fetch workspace and member in single query
    # Members list is deferred until modal opens for better initial load performance
    case Workspaces.get_workspace_and_member_by_slug(user, workspace_slug) do
      {:ok, workspace, current_member} ->
        documents = Documents.list_documents_for_workspace(user, workspace.id)
        projects = Projects.list_projects_for_workspace(user, workspace.id)

        # Load agents available in this workspace
        agents_result = Jarga.Agents.list_workspace_available_agents(workspace.id, user.id)

        # Subscribe to workspace-specific PubSub topic for real-time updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
        end

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:current_member, current_member)
         |> assign(:documents, documents)
         |> assign(:projects, projects)
         |> assign(:my_agents, agents_result.my_agents)
         |> assign(:other_agents, agents_result.other_agents)
         |> assign(:members, [])
         |> assign(:show_document_modal, false)
         |> assign(:show_project_modal, false)
         |> assign(:show_members_modal, false)
         |> assign(:document_form, to_form(%{"title" => ""}))
         |> assign(
           :project_form,
           to_form(Projects.new_project_changeset(), as: :project)
         )
         |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}))}

      {:error, :workspace_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: ~p"/app/workspaces")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  @impl true
  def handle_event("clone_agent", %{"agent-id" => agent_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    workspace_id = socket.assigns.workspace.id

    # Clone with workspace context for authorization
    case Agents.clone_shared_agent(agent_id, user_id, workspace_id: workspace_id) do
      {:ok, cloned_agent} ->
        # Add cloned agent to current workspace
        Agents.sync_agent_workspaces(cloned_agent.id, user_id, [workspace_id])

        # Refresh workspace-scoped agents
        agents_result = Agents.list_workspace_available_agents(workspace_id, user_id)

        {:noreply,
         socket
         |> assign(:my_agents, agents_result.my_agents)
         |> assign(:other_agents, agents_result.other_agents)
         |> put_flash(:info, "Agent '#{cloned_agent.name}' cloned successfully")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Agent not found")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Cannot clone this agent")}
    end
  end

  @impl true
  def handle_event("select_agent", %{"agent_id" => agent_id}, socket) do
    # Forward agent selection to the chat panel component
    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      selected_agent_id: agent_id
    )

    {:noreply, socket}
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

    case Documents.create_document(user, workspace_id, %{title: title}) do
      {:ok, document} ->
        # Reload documents
        documents = Documents.list_documents_for_workspace(user, workspace_id)

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
  def handle_event("show_project_modal", _params, socket) do
    {:noreply, assign(socket, show_project_modal: true)}
  end

  @impl true
  def handle_event("hide_project_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_project_modal, false)
     |> assign(:project_form, to_form(Projects.new_project_changeset()))}
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
         |> assign(
           :project_form,
           to_form(Projects.new_project_changeset(), as: :project)
         )
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

  @impl true
  def handle_event("show_members_modal", _params, socket) do
    # Load members when modal is opened (deferred loading for performance)
    members = Workspaces.list_members(socket.assigns.workspace.id)

    {:noreply,
     socket
     |> assign(:members, members)
     |> assign(:show_members_modal, true)}
  end

  @impl true
  def handle_event("hide_members_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_members_modal, false)
     |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}))}
  end

  @impl true
  def handle_event("invite_member", %{"email" => email, "role" => role}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    role_atom = String.to_existing_atom(role)

    case Workspaces.invite_member(user, workspace_id, email, role_atom) do
      {:ok, {:member_added, _member}} ->
        # Reload members
        members = Workspaces.list_members(workspace_id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}))
         |> put_flash(:info, "Member added successfully and notified via email")}

      {:ok, {:invitation_sent, _invitation}} ->
        # Reload members (to show pending invitation)
        members = Workspaces.list_members(workspace_id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}))
         |> put_flash(:info, "Invitation sent via email")}

      {:error, :invalid_role} ->
        {:noreply, put_flash(socket, :error, "Invalid role selected")}

      {:error, :already_member} ->
        {:noreply, put_flash(socket, :error, "User is already a member of this workspace")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to invite members")}

      {:error, :workspace_not_found} ->
        {:noreply, put_flash(socket, :error, "Workspace not found")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to invite member")}
    end
  end

  @impl true
  def handle_event("change_role", %{"email" => email, "value" => new_role}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    role_atom = String.to_existing_atom(new_role)

    case Workspaces.change_member_role(user, workspace_id, email, role_atom) do
      {:ok, _updated_member} ->
        # Reload members
        members = Workspaces.list_members(workspace_id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> put_flash(:info, "Member role updated successfully")}

      {:error, :cannot_change_owner_role} ->
        {:noreply, put_flash(socket, :error, "Cannot change the owner's role")}

      {:error, :member_not_found} ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to change roles")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to change member role")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"email" => email}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id

    case Workspaces.remove_member(user, workspace_id, email) do
      {:ok, _deleted_member} ->
        # Reload members
        members = Workspaces.list_members(workspace_id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> put_flash(:info, "Member removed successfully")}

      {:error, :cannot_remove_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot remove the workspace owner")}

      {:error, :member_not_found} ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to remove members")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member")}
    end
  end

  @impl true
  def handle_info({:project_added, _project_id}, socket) do
    # Reload projects when a new project is added
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    projects = Projects.list_projects_for_workspace(user, workspace_id)

    {:noreply, assign(socket, projects: projects)}
  end

  @impl true
  def handle_info({:project_removed, _project_id}, socket) do
    # Reload projects when a project is removed
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    projects = Projects.list_projects_for_workspace(user, workspace_id)

    {:noreply, assign(socket, projects: projects)}
  end

  @impl true
  def handle_info({:document_visibility_changed, _document_id, _is_public}, socket) do
    # Reload documents when a document's visibility changes
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    documents = Documents.list_documents_for_workspace(user, workspace_id)

    {:noreply, assign(socket, documents: documents)}
  end

  @impl true
  def handle_info({:document_pinned_changed, document_id, is_pinned}, socket) do
    # Update document pinned state in the list
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
  def handle_info({:document_created, document}, socket) do
    # Add new document to the list if it belongs to this workspace
    if document.workspace_id == socket.assigns.workspace.id do
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
    # Update project name in the list
    projects =
      Enum.map(socket.assigns.projects, fn project ->
        if project.id == project_id do
          %{project | name: name}
        else
          project
        end
      end)

    {:noreply, assign(socket, projects: projects)}
  end

  @impl true
  def handle_info({:member_joined, _user_id}, socket) do
    # Reload members list if modal is open
    if socket.assigns.show_members_modal do
      members = Workspaces.list_members(socket.assigns.workspace.id)
      {:noreply, assign(socket, members: members)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:invitation_declined, _user_id}, socket) do
    # Reload members list if modal is open
    if socket.assigns.show_members_modal do
      members = Workspaces.list_members(socket.assigns.workspace.id)
      {:noreply, assign(socket, members: members)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:workspace_agent_updated, _agent}, socket) do
    # Reload workspace agents and send to chat panel
    workspace_id = socket.assigns.workspace.id
    user = socket.assigns.current_scope.user

    # Reload for chat panel (flat list with enabled only)
    agents = Jarga.Agents.get_workspace_agents_list(workspace_id, user.id, enabled_only: true)

    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      workspace_agents: agents,
      from_pubsub: true
    )

    # Reload for workspace overview page (my_agents and other_agents)
    agents_result = Jarga.Agents.list_workspace_available_agents(workspace_id, user.id)

    {:noreply,
     socket
     |> assign(:my_agents, agents_result.my_agents)
     |> assign(:other_agents, agents_result.other_agents)}
  end

  # Chat panel streaming messages
  handle_chat_messages()

  # Catch-all for unhandled messages (e.g., email notifications from Swoosh)
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
