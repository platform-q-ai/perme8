defmodule JargaWeb.AppLive.Agents.Form do
  @moduledoc """
  LiveView for creating and editing user agents.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Agents

  alias Agents.Domain.Events.{
    AgentUpdated,
    AgentDeleted,
    AgentAddedToWorkspace,
    AgentRemovedFromWorkspace
  }

  alias Jarga.Workspaces
  alias JargaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      user = socket.assigns.current_scope.user

      # Subscribe to workspace topic(s) for agent events (AgentUpdated, AgentDeleted, etc.)
      # Agent events are broadcast to workspace topics, not user topics.
      case Map.get(socket.assigns.current_scope, :workspace) do
        nil ->
          # No workspace context — subscribe to all user's workspaces
          workspaces = Workspaces.list_workspaces_for_user(user)

          Enum.each(workspaces, fn workspace ->
            Perme8.Events.subscribe("events:workspace:#{workspace.id}")
          end)

        workspace ->
          Perme8.Events.subscribe("events:workspace:#{workspace.id}")
      end
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, %{assigns: %{live_action: :view}} = socket) do
    # View mode - load agent from workspace (can be other's agent)
    user = socket.assigns.current_scope.user
    workspace = Map.get(socket.assigns.current_scope, :workspace)
    return_to = Map.get(params, "return_to", "agents")
    workspace_slug = Map.get(params, "workspace_slug")

    workspace_agents = load_workspace_agents(workspace, user.id)
    agent = Enum.find(workspace_agents, &(&1.id == id))

    case agent do
      nil ->
        {:noreply, redirect_agent_not_found(socket)}

      agent ->
        {:noreply, setup_view_mode(socket, agent, user, return_to, workspace_slug)}
    end
  end

  def handle_params(%{"id" => id} = params, _url, socket) do
    # Edit mode - try to get agent through context
    user = socket.assigns.current_scope.user
    user_agents = Agents.list_user_agents(user.id)
    agent = Enum.find(user_agents, &(&1.id == id))
    return_to = Map.get(params, "return_to", "agents")
    workspace_slug = Map.get(params, "workspace_slug")

    case agent do
      nil ->
        {:noreply, redirect_agent_not_found(socket)}

      agent ->
        {:noreply, setup_edit_mode(socket, agent, user, return_to, workspace_slug)}
    end
  end

  def handle_params(params, _url, socket) do
    # New mode - initialize with empty agent attributes
    initial_attrs = %{
      "name" => "",
      "description" => "",
      "system_prompt" => "",
      "model" => "",
      "temperature" => "0.7",
      "visibility" => "PRIVATE"
    }

    # Load user's workspaces
    user = socket.assigns.current_scope.user
    workspaces = Workspaces.list_workspaces_for_user(user)
    return_to = Map.get(params, "return_to", "agents")
    workspace_slug = Map.get(params, "workspace_slug")

    {:noreply,
     socket
     |> assign(:form, to_form(initial_attrs, as: :agent))
     |> assign(:agent, nil)
     |> assign(:workspaces, workspaces)
     |> assign(:selected_workspace_ids, [])
     |> assign(:page_title, "New Agent")
     |> assign(:read_only, false)
     |> assign(:is_owner, true)
     |> assign(:return_to, return_to)
     |> assign(:workspace_slug, workspace_slug)}
  end

  @impl true
  def handle_event("clone_agent", _params, socket) do
    agent_id = socket.assigns.agent.id
    user_id = socket.assigns.current_scope.user.id

    # Get workspace_id from current_scope if available
    opts =
      case Map.get(socket.assigns.current_scope, :workspace) do
        nil -> []
        workspace -> [workspace_id: workspace.id]
      end

    case Agents.clone_shared_agent(agent_id, user_id, opts) do
      {:ok, cloned_agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent cloned successfully as '#{cloned_agent.name}'")
         |> push_navigate(to: ~p"/app/agents/#{cloned_agent.id}/edit")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Agent not found")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Cannot clone this agent")}
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    # Update selected workspace IDs when checkboxes change
    workspace_ids = params["workspace_ids"] || []
    {:noreply, assign(socket, :selected_workspace_ids, workspace_ids)}
  end

  @impl true
  def handle_event("save", params, socket) do
    # Security: Prevent saves in read-only mode (defense in depth)
    if socket.assigns[:read_only] do
      {:noreply, put_flash(socket, :error, "Cannot save in view-only mode")}
    else
      agent_params = params["agent"] || %{}
      workspace_ids = params["workspace_ids"] || []
      save_agent(socket, socket.assigns.agent, agent_params, workspace_ids)
    end
  end

  defp save_agent(socket, nil, agent_params, workspace_ids) do
    # Create new agent
    user_id = socket.assigns.current_scope.user.id
    params = Map.put(agent_params, "user_id", user_id)

    case Agents.create_user_agent(params) do
      {:ok, agent} ->
        # Sync workspace associations
        Agents.sync_agent_workspaces(agent.id, user_id, workspace_ids)

        {:noreply,
         socket
         |> put_flash(:info, "Agent created successfully")
         |> push_navigate(to: ~p"/app/agents")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_agent(socket, agent, agent_params, workspace_ids) do
    # Update existing agent
    user_id = socket.assigns.current_scope.user.id

    case Agents.update_user_agent(agent.id, user_id, agent_params) do
      {:ok, _agent} ->
        # Sync workspace associations
        Agents.sync_agent_workspaces(agent.id, user_id, workspace_ids)

        {:noreply,
         socket
         |> put_flash(:info, "Agent updated successfully")
         |> push_navigate(to: ~p"/app/agents")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp get_workspace_name(workspaces, workspace_id) do
    case Enum.find(workspaces, &(&1.id == workspace_id)) do
      nil -> "Unknown Workspace"
      workspace -> workspace.name
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="w-full space-y-6">
        <.header>
          {@page_title}
          <:subtitle>Configure your AI agent</:subtitle>
        </.header>

        <.form
          for={@form}
          phx-change={if @read_only, do: nil, else: "validate"}
          phx-submit={if @read_only, do: nil, else: "save"}
          class="space-y-6"
        >
          <.input field={@form[:name]} type="text" label="Name" disabled={@read_only} />
          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            disabled={@read_only}
          />
          <.input
            field={@form[:system_prompt]}
            type="textarea"
            label="System Prompt"
            rows="6"
            disabled={@read_only}
          />
          <.input field={@form[:model]} type="text" label="Model" disabled={@read_only} />
          <.input
            field={@form[:temperature]}
            type="number"
            label="Temperature"
            step="0.1"
            disabled={@read_only}
          />
          <.input
            field={@form[:visibility]}
            type="select"
            label="Visibility"
            options={[{"Private", "PRIVATE"}, {"Shared", "SHARED"}]}
            disabled={@read_only}
          />

          <%= if @read_only do %>
            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-medium">Workspaces</span>
              </label>
              <div class="flex flex-wrap gap-2">
                <%= if Enum.empty?(@selected_workspace_ids) do %>
                  <span class="text-sm text-base-content/70">Not shared in any workspace</span>
                <% else %>
                  <%= for workspace_id <- @selected_workspace_ids do %>
                    <span class="badge badge-ghost">
                      {get_workspace_name(@workspaces, workspace_id)}
                    </span>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="form-control">
              <label class="label">
                <span class="label-text text-sm font-medium">Workspaces</span>
              </label>
              <div class="space-y-2 pl-2">
                <%= if Enum.empty?(@workspaces) do %>
                  <p class="text-sm text-base-content/70">
                    You don't belong to any workspaces yet. Create or join a workspace to share this agent.
                  </p>
                <% else %>
                  <%= for workspace <- @workspaces do %>
                    <label class="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        name="workspace_ids[]"
                        value={workspace.id}
                        checked={workspace.id in @selected_workspace_ids}
                        class="checkbox checkbox-sm"
                      />
                      <span class="text-sm">{workspace.name}</span>
                    </label>
                  <% end %>
                <% end %>
              </div>
              <label class="label">
                <span class="text-xs text-base-content/70">
                  Select which workspaces can access this agent
                </span>
              </label>
            </div>
          <% end %>

          <div class="flex gap-4">
            <%= if @read_only do %>
              <%= if !@is_owner do %>
                <.button
                  type="button"
                  variant="primary"
                  phx-click="clone_agent"
                  phx-disable-with="Cloning..."
                >
                  <.icon name="hero-document-duplicate" class="size-4" /> Clone Agent
                </.button>
              <% end %>
              <.link navigate={get_back_path(@return_to, @workspace_slug)} class="btn btn-ghost">
                {get_back_label(@return_to)}
              </.link>
            <% else %>
              <.button type="submit" variant="primary">
                Save Agent
              </.button>
              <.link navigate={get_back_path(@return_to, @workspace_slug)} class="btn btn-ghost">
                Cancel
              </.link>
            <% end %>
          </div>
        </.form>
      </div>
    </Layouts.admin>
    """
  end

  # Private helper functions to reduce cyclomatic complexity

  defp load_workspace_agents(nil, user_id) do
    # Fallback: Load agents viewable by user (their own + all shared agents)
    # This allows accessing /agents/:id/view directly without workspace context
    Agents.list_viewable_agents(user_id)
  end

  defp load_workspace_agents(workspace, user_id) do
    # Get all workspace agents (includes shared agents)
    Agents.get_workspace_agents_list(workspace.id, user_id)
  end

  defp redirect_agent_not_found(socket) do
    socket
    |> put_flash(:error, "Agent not found")
    |> push_navigate(to: ~p"/app/agents")
  end

  defp setup_view_mode(socket, agent, user, return_to, workspace_slug) do
    agent_attrs = build_agent_attrs(agent)
    workspaces = Workspaces.list_workspaces_for_user(user)
    selected_workspace_ids = Agents.get_agent_workspace_ids(agent.id)

    socket
    |> assign(:form, to_form(agent_attrs, as: :agent))
    |> assign(:agent, agent)
    |> assign(:workspaces, workspaces)
    |> assign(:selected_workspace_ids, selected_workspace_ids)
    |> assign(:page_title, "View Agent")
    |> assign(:read_only, true)
    |> assign(:is_owner, agent.user_id == user.id)
    |> assign(:return_to, return_to)
    |> assign(:workspace_slug, workspace_slug)
  end

  defp setup_edit_mode(socket, agent, user, return_to, workspace_slug) do
    agent_attrs = build_agent_attrs(agent)
    workspaces = Workspaces.list_workspaces_for_user(user)
    selected_workspace_ids = Agents.get_agent_workspace_ids(agent.id)

    socket
    |> assign(:form, to_form(agent_attrs, as: :agent))
    |> assign(:agent, agent)
    |> assign(:workspaces, workspaces)
    |> assign(:selected_workspace_ids, selected_workspace_ids)
    |> assign(:page_title, "Edit Agent")
    |> assign(:read_only, false)
    |> assign(:is_owner, true)
    |> assign(:return_to, return_to)
    |> assign(:workspace_slug, workspace_slug)
  end

  defp build_agent_attrs(agent) do
    %{
      "name" => agent.name || "",
      "description" => agent.description || "",
      "system_prompt" => agent.system_prompt || "",
      "model" => agent.model || "",
      "temperature" => to_string(agent.temperature || 0.7),
      "visibility" => agent.visibility || "PRIVATE"
    }
  end

  defp get_back_path("workspace", workspace_slug) when is_binary(workspace_slug) do
    ~p"/app/workspaces/#{workspace_slug}"
  end

  defp get_back_path(_, _), do: ~p"/app/agents"

  defp get_back_label("workspace"), do: "Back to Workspace"
  defp get_back_label(_), do: "Back to Agents"

  @impl true
  def handle_info(%AgentUpdated{}, socket), do: {:noreply, reload_agents_for_chat_panel(socket)}

  @impl true
  def handle_info(%AgentDeleted{}, socket), do: {:noreply, reload_agents_for_chat_panel(socket)}

  @impl true
  def handle_info(%AgentAddedToWorkspace{}, socket),
    do: {:noreply, reload_agents_for_chat_panel(socket)}

  @impl true
  def handle_info(%AgentRemovedFromWorkspace{}, socket),
    do: {:noreply, reload_agents_for_chat_panel(socket)}

  # Chat panel streaming messages
  handle_chat_messages()

  defp reload_agents_for_chat_panel(socket) do
    user = socket.assigns.current_scope.user
    agents = Agents.list_user_agents(user.id)

    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      workspace_agents: agents,
      from_pubsub: true
    )

    socket
  end
end
