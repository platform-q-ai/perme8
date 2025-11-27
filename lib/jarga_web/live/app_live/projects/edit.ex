defmodule JargaWeb.AppLive.Projects.Edit do
  @moduledoc """
  LiveView for editing project details.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.{Workspaces, Projects}
  alias Jarga.Projects.Infrastructure.Schemas.ProjectSchema
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <:breadcrumbs navigate={~p"/app"}>Home</:breadcrumbs>
      <:breadcrumbs navigate={~p"/app/workspaces"}>Workspaces</:breadcrumbs>
      <:breadcrumbs navigate={~p"/app/workspaces/#{@workspace.slug}"}>{@workspace.name}</:breadcrumbs>
      <:breadcrumbs navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}"}>
        {@project.name}
      </:breadcrumbs>
      <:breadcrumbs>Edit</:breadcrumbs>

      <div class="w-full space-y-6">
        <.header>
          Edit Project
          <:subtitle>
            <.link
              navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}"}
              class="text-sm hover:underline"
            >
              ← Back to {@project.name}
            </.link>
          </:subtitle>
        </.header>

        <.form for={@form} id="project-form" phx-submit="save" class="space-y-6">
          <.input
            field={@form[:name]}
            type="text"
            label="Name"
            placeholder="My Project"
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Describe your project..."
          />

          <.input field={@form[:color]} type="text" label="Color" placeholder="#10B981" />

          <div class="flex gap-4">
            <.button type="submit" variant="primary">
              Update Project
            </.button>
            <.link
              navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}"}
              class="btn btn-ghost"
            >
              Cancel
            </.link>
          </div>
        </.form>
      </div>
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
    changeset = ProjectSchema.changeset(project, %{})

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:project, project)
     |> assign(:form, to_form(changeset, as: :project))}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id
    project_id = socket.assigns.project.id

    case Projects.update_project(user, workspace_id, project_id, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully")
         |> push_navigate(
           to: ~p"/app/workspaces/#{socket.assigns.workspace.slug}/projects/#{project.slug}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update project")}
    end
  end

  # Chat panel streaming messages
  handle_chat_messages()
end
