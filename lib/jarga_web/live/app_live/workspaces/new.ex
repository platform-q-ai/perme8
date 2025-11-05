defmodule JargaWeb.AppLive.Workspaces.New do
  @moduledoc """
  LiveView for creating a new workspace.
  """

  use JargaWeb, :live_view

  alias Jarga.Workspaces
  alias Jarga.Workspaces.Workspace
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto space-y-8">
        <.breadcrumbs>
          <:crumb navigate={~p"/app"}>Home</:crumb>
          <:crumb navigate={~p"/app/workspaces"}>Workspaces</:crumb>
          <:crumb>New</:crumb>
        </.breadcrumbs>

        <div>
          <.header>
            New Workspace
            <:subtitle>Create a new workspace to organize your work</:subtitle>
          </.header>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <.form
              for={@form}
              id="workspace-form"
              phx-submit="save"
              class="space-y-4"
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

              <div class="flex gap-2 justify-end">
                <.link navigate={~p"/app/workspaces"} class="btn btn-ghost">
                  Cancel
                </.link>
                <.button type="submit" variant="primary">
                  Create Workspace
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = Workspace.changeset(%Workspace{}, %{})

    {:ok,
     socket
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    user = socket.assigns.current_scope.user

    case Workspaces.create_workspace(user, workspace_params) do
      {:ok, _workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace created successfully")
         |> push_navigate(to: ~p"/app/workspaces")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
