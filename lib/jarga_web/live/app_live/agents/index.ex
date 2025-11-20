defmodule JargaWeb.AppLive.Agents.Index do
  @moduledoc """
  LiveView for managing user's personal agents (master agent list).
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.Agents
  alias JargaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Agents")
     |> load_agents()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "My Agents")}
  end

  defp load_agents(socket) do
    agents = Agents.list_user_agents(socket.assigns.current_scope.user.id)
    assign(socket, :agents, agents)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Agents.delete_user_agent(id, socket.assigns.current_scope.user.id) do
      {:ok, _agent} ->
        {:noreply,
         socket
         |> load_agents()
         |> put_flash(:info, "Agent deleted successfully")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Agent not found")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to delete this agent")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <.header>
            My Agents
            <:subtitle>Manage your personal agent library</:subtitle>
          </.header>

          <.button variant="primary" navigate={~p"/app/agents/new"}>
            <.icon name="hero-plus" class="size-4" /> New Agent
          </.button>
        </div>

        <%= if @agents == [] do %>
          <div class="card bg-base-200">
            <div class="card-body text-center">
              <div class="flex flex-col items-center gap-4 py-8">
                <.icon name="hero-cpu-chip" class="size-16 opacity-50" />
                <div>
                  <h3 class="text-base font-semibold">No agents yet</h3>
                  <p class="text-base-content/70">
                    Create your first agent to get started
                  </p>
                </div>
                <.link navigate={~p"/app/agents/new"} class="btn btn-primary">
                  Create Agent
                </.link>
              </div>
            </div>
          </div>
        <% else %>
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
                <%= for agent <- @agents do %>
                  <tr>
                    <td class="text-sm font-medium">{agent.name}</td>
                    <td class="text-sm">{agent.model || "Not set"}</td>
                    <td class="text-sm text-right">
                      <div class="join">
                        <.link
                          navigate={~p"/app/agents/#{agent.id}/edit"}
                          class="btn btn-sm btn-ghost join-item"
                        >
                          <.icon name="hero-pencil" class="size-4" />
                        </.link>
                        <.button
                          variant="ghost"
                          size="sm"
                          phx-click="delete"
                          phx-value-id={agent.id}
                          data-confirm="Are you sure you want to delete this agent?"
                          class="join-item"
                        >
                          <.icon name="hero-trash" class="size-4" />
                        </.button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_info({:workspace_agent_updated, _agent}, socket) do
    # Reload all user's agents when an agent is created/updated/deleted
    user = socket.assigns.current_scope.user
    agents = Agents.list_user_agents(user.id)

    # Update the chat panel with fresh agent list
    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      workspace_agents: agents,
      from_pubsub: true
    )

    # Reload the agents list on this page too
    {:noreply, assign(socket, :agents, agents)}
  end

  # Chat panel streaming messages
  handle_chat_messages()
end
