defmodule JargaWeb.AppLive.Workspaces.New do
  @moduledoc """
  LiveView for creating a new workspace.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.Workspaces
  alias Jarga.Workspaces.Workspace
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <:breadcrumbs navigate={~p"/app"}>Home</:breadcrumbs>
      <:breadcrumbs navigate={~p"/app/workspaces"}>Workspaces</:breadcrumbs>
      <:breadcrumbs>New</:breadcrumbs>

      <div class="w-full space-y-6">
        <.header>
          New Workspace
          <:subtitle>Create a new workspace to organize your work</:subtitle>
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
              Create Workspace
            </.button>
            <.link navigate={~p"/app/workspaces"} class="btn btn-ghost">
              Cancel
            </.link>
          </div>
        </.form>
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

  # Chat panel streaming messages
  handle_chat_messages()
end
