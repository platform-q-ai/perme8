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

        <div class="flex items-center justify-end">
          <div class="flex gap-2">
            <.link navigate={~p"/app/workspaces/#{@workspace.id}/edit"} class="btn btn-ghost">
              <.icon name="hero-pencil" class="size-5" />
              Edit
            </.link>
            <.button variant="ghost" phx-click="show_members_modal">
              <.icon name="hero-user-group" class="size-5" />
              Manage Members
            </.button>
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

      <%!-- Members Management Modal --%>
      <%= if @show_members_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-4xl">
            <h3 class="font-bold text-lg mb-4">Manage Members</h3>

            <%!-- Invite Section --%>
            <div class="mb-6">
              <h4 class="font-semibold mb-3">Invite New Member</h4>
              <.form
                for={@invite_form}
                id="invite-form"
                phx-submit="invite_member"
                class="flex gap-2"
              >
                <.input
                  field={@invite_form[:email]}
                  type="email"
                  placeholder="user@example.com"
                  class="flex-1"
                  required
                />

                <.input
                  field={@invite_form[:role]}
                  type="select"
                  options={[
                    {"Admin", "admin"},
                    {"Member", "member"},
                    {"Guest", "guest"}
                  ]}
                  class="w-32"
                  required
                />

                <.button type="submit" variant="primary">
                  <.icon name="hero-user-plus" class="size-4" />
                  Invite
                </.button>
              </.form>
            </div>

            <div class="divider"></div>

            <%!-- Members List --%>
            <div>
              <h4 class="font-semibold mb-3">
                Current Members ({length(@members)})
              </h4>

              <div class="overflow-x-auto max-h-96">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Email</th>
                      <th>Role</th>
                      <th>Status</th>
                      <th>Joined</th>
                      <th class="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for member <- @members do %>
                      <tr>
                        <td class="font-medium">{member.email}</td>
                        <td>
                          <%= if member.role == :owner do %>
                            <span class="badge badge-primary badge-sm">Owner</span>
                          <% else %>
                            <select
                              class="select select-xs select-bordered"
                              phx-change="change_role"
                              phx-value-email={member.email}
                            >
                              <option value="admin" selected={member.role == :admin}>Admin</option>
                              <option value="member" selected={member.role == :member}>
                                Member
                              </option>
                              <option value="guest" selected={member.role == :guest}>Guest</option>
                            </select>
                          <% end %>
                        </td>
                        <td>
                          <%= if member.joined_at do %>
                            <span class="badge badge-success badge-xs">Active</span>
                          <% else %>
                            <span class="badge badge-warning badge-xs">Pending</span>
                          <% end %>
                        </td>
                        <td class="text-sm text-base-content/70">
                          <%= if member.joined_at do %>
                            {Calendar.strftime(member.joined_at, "%b %d, %Y")}
                          <% else %>
                            <span class="text-base-content/50">—</span>
                          <% end %>
                        </td>
                        <td class="text-right">
                          <%= if member.role != :owner do %>
                            <.button
                              variant="error"
                              size="xs"
                              phx-click="remove_member"
                              phx-value-email={member.email}
                              data-confirm="Are you sure you want to remove this member?"
                            >
                              <.icon name="hero-x-mark" class="size-3" />
                              Remove
                            </.button>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>

            <div class="modal-action">
              <.button variant="ghost" phx-click="hide_members_modal">
                Close
              </.button>
            </div>
          </div>
          <div class="modal-backdrop" phx-click="hide_members_modal"></div>
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
  def mount(%{"id" => workspace_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    case Workspaces.get_workspace(user, workspace_id) do
      {:ok, workspace} ->
        projects = Projects.list_projects_for_workspace(user, workspace_id)
        members = Workspaces.list_members(workspace_id)

        {:ok,
         socket
         |> assign(:workspace, workspace)
         |> assign(:projects, projects)
         |> assign(:members, members)
         |> assign(:show_project_modal, false)
         |> assign(:show_members_modal, false)
         |> assign(:project_form, to_form(Project.changeset(%Project{}, %{})))
         |> assign(:invite_form, to_form(%{"email" => "", "role" => "member"}))}

      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have access to this workspace")
         |> push_navigate(to: ~p"/app/workspaces")}

      {:error, :workspace_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found")
         |> push_navigate(to: ~p"/app/workspaces")}
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
end
