defmodule JargaWeb.AppLive.Workspaces.Show do
  use JargaWeb, :live_view

  import JargaWeb.Live.PermissionsHelper

  alias Jarga.{Workspaces, Projects, Pages}
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

        <div class="flex items-center justify-end">
          <div class="flex gap-2">
            <%= if can_edit_workspace?(@current_member) do %>
              <.link navigate={~p"/app/workspaces/#{@workspace.slug}/edit"} class="btn btn-ghost">
                <.icon name="hero-pencil" class="size-5" /> Edit
              </.link>
            <% end %>
            <%= if can_manage_members?(@current_member) do %>
              <.button variant="ghost" phx-click="show_members_modal">
                <.icon name="hero-user-group" class="size-5" /> Manage Members
              </.button>
            <% end %>
            <%= if can_delete_workspace?(@current_member) do %>
              <.button
                variant="error"
                phx-click="delete_workspace"
                data-confirm="Are you sure you want to delete this workspace? All projects will also be deleted."
              >
                <.icon name="hero-trash" class="size-5" /> Delete Workspace
              </.button>
            <% end %>
            <%= if can_create_project?(@current_member) do %>
              <.button variant="primary" phx-click="show_project_modal">
                New Project
              </.button>
            <% end %>
          </div>
        </div>

        <%= if @workspace.description do %>
          <div class="card bg-base-200">
            <div class="card-body">
              <p>{@workspace.description}</p>
            </div>
          </div>
        <% end %>

        <%!-- Pages Section --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Pages</h2>
            <%= if can_create_page?(@current_member) do %>
              <.button variant="primary" size="sm" phx-click="show_page_modal">
                <.icon name="hero-document-plus" class="size-4" /> New Page
              </.button>
            <% end %>
          </div>

          <%= if @pages == [] do %>
            <div class="card bg-base-200">
              <div class="card-body text-center">
                <div class="flex flex-col items-center gap-4 py-8">
                  <.icon name="hero-document" class="size-16 opacity-50" />
                  <div>
                    <h3 class="text-lg font-semibold">No pages yet</h3>
                    <p class="text-base-content/70">
                      <%= if can_create_page?(@current_member) do %>
                        Create your first page to start documenting
                      <% else %>
                        No pages have been created yet
                      <% end %>
                    </p>
                  </div>
                  <%= if can_create_page?(@current_member) do %>
                    <.button variant="primary" phx-click="show_page_modal">
                      Create Page
                    </.button>
                  <% end %>
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
                        <span class="text-xs">📌</span> Pinned
                      </div>
                    <% end %>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Projects Section --%>
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
            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              <%= for project <- @projects do %>
                <.link
                  navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{project.slug}"}
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
                  <h4 class="font-semibold mb-3 flex items-center gap-2">
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
                  <h4 class="font-semibold flex items-center gap-2">
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
                          <th class="font-semibold">Member</th>
                          <th class="font-semibold">Role</th>
                          <th class="font-semibold">Status</th>
                          <th class="font-semibold">Joined</th>
                          <th class="font-semibold text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for member <- @members do %>
                          <tr class="hover">
                            <td>
                              <div class="flex items-center gap-2">
                                <div class="avatar placeholder">
                                  <div class="bg-neutral text-neutral-content w-8 rounded-full">
                                    <span class="text-xs">
                                      {member.email |> String.slice(0..1) |> String.upcase()}
                                    </span>
                                  </div>
                                </div>
                                <span class="font-medium">{member.email}</span>
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
                            <td class="text-sm text-base-content/70">
                              <%= if member.joined_at do %>
                                {Calendar.strftime(member.joined_at, "%b %d, %Y")}
                              <% else %>
                                <span class="text-base-content/50 italic">Not yet</span>
                              <% end %>
                            </td>
                            <td class="text-right">
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
  def mount(%{"slug" => workspace_slug}, _session, socket) do
    user = socket.assigns.current_scope.user

    case Workspaces.get_workspace_by_slug(user, workspace_slug) do
      {:ok, workspace} ->
        pages = Pages.list_pages_for_workspace(user, workspace.id)
        projects = Projects.list_projects_for_workspace(user, workspace.id)
        members = Workspaces.list_members(workspace.id)

        # Get the current user's workspace member record for permission checking
        {:ok, current_member} = Workspaces.get_member(user, workspace.id)

        # Subscribe to workspace-specific PubSub topic for real-time updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
        end

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:current_member, current_member)
         |> assign(:pages, pages)
         |> assign(:projects, projects)
         |> assign(:members, members)
         |> assign(:show_page_modal, false)
         |> assign(:show_project_modal, false)
         |> assign(:show_members_modal, false)
         |> assign(:page_form, to_form(%{"title" => ""}))
         |> assign(:project_form, to_form(Project.changeset(%Project{}, %{})))
         |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}))}

      {:error, :workspace_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: ~p"/app/workspaces")}
    end
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

    case Pages.create_page(user, workspace_id, %{title: title}) do
      {:ok, page} ->
        # Reload pages
        pages = Pages.list_pages_for_workspace(user, workspace_id)

        {:noreply,
         socket
         |> assign(:pages, pages)
         |> assign(:show_page_modal, false)
         |> assign(:page_form, to_form(%{"title" => ""}))
         |> put_flash(:info, "Page created successfully")
         |> push_navigate(
           to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}/pages/#{page.slug}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, page_form: to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create page")}
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

  @impl true
  def handle_event("show_members_modal", _params, socket) do
    {:noreply, assign(socket, show_members_modal: true)}
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
  def handle_info({:page_visibility_changed, _page_id, _is_public}, socket) do
    # Reload pages when a page's visibility changes
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    pages = Pages.list_pages_for_workspace(user, workspace_id)

    {:noreply, assign(socket, pages: pages)}
  end

  @impl true
  def handle_info({:page_pinned_changed, page_id, is_pinned}, socket) do
    # Update page pinned state in the list
    pages =
      Enum.map(socket.assigns.pages, fn page ->
        if page.id == page_id do
          %{page | is_pinned: is_pinned}
        else
          page
        end
      end)

    {:noreply, assign(socket, pages: pages)}
  end

  @impl true
  def handle_info({:page_title_changed, page_id, title}, socket) do
    # Update page title in the list
    pages =
      Enum.map(socket.assigns.pages, fn page ->
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
end
