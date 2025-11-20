defmodule JargaWeb.AppLive.Workspaces.Edit do
  @moduledoc """
  LiveView for editing workspace details and managing members.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.Workspaces
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <:breadcrumbs navigate={~p"/app"}>Home</:breadcrumbs>
      <:breadcrumbs navigate={~p"/app/workspaces"}>Workspaces</:breadcrumbs>
      <:breadcrumbs navigate={~p"/app/workspaces/#{@workspace.slug}"}>{@workspace.name}</:breadcrumbs>
      <:breadcrumbs>Edit</:breadcrumbs>

      <div class="w-full space-y-6">
        <.header>
          Edit Workspace
          <:subtitle>
            <.link navigate={~p"/app/workspaces/#{@workspace.slug}"} class="text-sm hover:underline">
              ← Back to {@workspace.name}
            </.link>
          </:subtitle>
        </.header>

        <.form
          for={@form}
          id="workspace-form"
          phx-submit="save"
          class="space-y-6"
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Name"
            placeholder="My Workspace"
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            placeholder="Describe your workspace..."
          />

          <.input
            field={@form[:color]}
            type="text"
            label="Color"
            placeholder="#4A90E2"
          />

          <div class="flex gap-4">
            <.button type="submit" variant="primary">
              Update Workspace
            </.button>
            <.link navigate={~p"/app/workspaces/#{@workspace.slug}"} class="btn btn-ghost">
              Cancel
            </.link>
          </div>
        </.form>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(%{"workspace_slug" => workspace_slug}, _session, socket) do
    user = socket.assigns.current_scope.user

    # This will raise if user is not a member
    workspace = Workspaces.get_workspace_by_slug!(user, workspace_slug)
    changeset = Workspaces.Workspace.changeset(workspace, %{})

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id

    case Workspaces.update_workspace(user, workspace_id, workspace_params) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace updated successfully")
         |> push_navigate(to: ~p"/app/workspaces/#{workspace.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update workspace")}
    end
  end

  # Chat panel streaming messages
  handle_chat_messages()
end
