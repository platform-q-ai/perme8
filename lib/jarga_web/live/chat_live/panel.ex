defmodule JargaWeb.ChatLive.Panel do
  @moduledoc """
  Global chat panel LiveView component.

  Provides an always-accessible chat interface that can be toggled from any page.
  In PR #1, this chats with the current document content.
  Future PRs will add document chat functionality.
  """
  use JargaWeb, :live_component

  import JargaWeb.ChatLive.Components.Message

  alias Jarga.Agents

  @impl true
  def mount(socket) do
    {:ok,
     socket
     # Initial server-side state (overridden by JavaScript hook based on screen size)
     # Desktop (≥1024px): opens by default
     # Mobile (<1024px): closed by default
     |> assign(:collapsed, true)
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:streaming, false)
     |> assign(:stream_buffer, "")
     |> assign(:error, nil)
     |> assign(:current_session_id, nil)
     |> assign(:view_mode, :chat)
     |> assign(:sessions, [])
     |> assign(:workspace_agents, [])
     |> assign(:selected_agent_id, nil)}
  end

  @impl true
  def update(assigns, socket) do
    # Store current selected_agent_id to preserve it across updates
    current_selected_agent_id = socket.assigns[:selected_agent_id]

    socket =
      socket
      |> assign(assigns)
      |> maybe_restore_session(assigns)
      |> maybe_load_workspace_agents(assigns)
      |> handle_workspace_agents_update(assigns)
      |> handle_agent_selection_update(assigns)
      |> handle_streaming_updates(assigns)
      |> preserve_selected_agent(current_selected_agent_id, assigns)

    {:ok, socket}
  end

  # Preserves selected_agent_id unless explicitly updated
  defp preserve_selected_agent(socket, previous_selected_agent_id, assigns) do
    # If the update didn't explicitly include selected_agent_id, restore the previous value
    if !Map.has_key?(assigns, :selected_agent_id) && previous_selected_agent_id do
      assign(socket, :selected_agent_id, previous_selected_agent_id)
    else
      socket
    end
  end

  # Handles agent selection updates sent via send_update from parent LiveView
  defp handle_agent_selection_update(socket, assigns) do
    if Map.has_key?(assigns, :selected_agent_id) do
      assign(socket, :selected_agent_id, assigns.selected_agent_id)
    else
      socket
    end
  end

  # Loads workspace agents on first mount
  # When in a workspace: loads workspace-scoped agents (shared + user's own)
  # When outside workspace (e.g. dashboard): loads all user's agents for testing
  defp maybe_load_workspace_agents(socket, assigns) do
    if socket.assigns[:agents_loaded] do
      socket
    else
      workspace_id = get_nested(assigns, [:current_workspace, :id])
      current_user = get_nested(assigns, [:current_user])

      agents =
        cond do
          workspace_id && current_user ->
            # In workspace: get workspace-scoped agents
            Agents.get_workspace_agents_list(workspace_id, current_user.id, enabled_only: true)

          current_user ->
            # Outside workspace: get all user's agents for testing during creation/editing
            Agents.list_user_agents(current_user.id)

          true ->
            []
        end

      # Load selected agent from user preferences
      selected_agent_id =
        if workspace_id && current_user do
          Jarga.Accounts.get_selected_agent_id(current_user.id, workspace_id)
        else
          nil
        end

      socket
      |> assign(:workspace_agents, agents)
      |> assign(:agents_loaded, true)
      |> assign(:selected_agent_id, selected_agent_id)
      |> auto_select_first_agent(agents)
    end
  end

  # Auto-selects the first agent if no agent is currently selected
  defp auto_select_first_agent(socket, agents) do
    if socket.assigns.selected_agent_id == nil && !Enum.empty?(agents) do
      [first_agent | _] = agents
      assign(socket, :selected_agent_id, first_agent.id)
    else
      socket
    end
  end

  # Handles workspace agents updates sent via send_update from parent LiveView
  # This is triggered when agents are created/updated/deleted via PubSub
  defp handle_workspace_agents_update(socket, assigns) do
    if Map.has_key?(assigns, :workspace_agents) && Map.has_key?(assigns, :from_pubsub) do
      # Update from PubSub - refresh the agent list
      socket = assign(socket, :workspace_agents, assigns.workspace_agents)

      # Clear selection if the selected agent no longer exists, or auto-select first
      socket
      |> clear_invalid_agent_selection(assigns.workspace_agents)
      |> auto_select_first_agent(assigns.workspace_agents)
    else
      socket
    end
  end

  defp clear_invalid_agent_selection(socket, workspace_agents) do
    selected_agent_id = socket.assigns.selected_agent_id

    if selected_agent_id && !agent_exists?(workspace_agents, selected_agent_id) do
      assign(socket, :selected_agent_id, nil)
    else
      socket
    end
  end

  defp agent_exists?(workspace_agents, agent_id) do
    Enum.any?(workspace_agents, fn agent -> agent.id == agent_id end)
  end

  # Restores the most recent session from database on first mount
  defp maybe_restore_session(socket, assigns) do
    if socket.assigns[:session_restored] do
      socket
    else
      socket
      |> restore_user_session(assigns)
      |> assign(:session_restored, true)
    end
  end

  defp restore_user_session(socket, assigns) do
    current_user_id = get_nested(assigns, [:current_user, :id])

    if current_user_id do
      load_most_recent_session(socket, current_user_id)
    else
      socket
    end
  end

  defp load_most_recent_session(socket, user_id) do
    with {:ok, [most_recent_session | _]} <- Agents.list_sessions(user_id, limit: 1),
         {:ok, db_session} <- Agents.load_session(most_recent_session.id) do
      ui_messages = convert_messages_to_ui_format(db_session.messages)

      socket
      |> assign(:current_session_id, db_session.id)
      |> assign(:messages, ui_messages)
    else
      _ -> socket
    end
  end

  # Handles streaming message updates sent via send_update from parent
  defp handle_streaming_updates(socket, assigns) do
    cond do
      Map.has_key?(assigns, :chunk) ->
        handle_chunk(socket, assigns.chunk)

      Map.has_key?(assigns, :done) ->
        handle_done(socket, assigns.done)

      Map.has_key?(assigns, :error) ->
        handle_error(socket, assigns.error)

      true ->
        socket
    end
  end

  defp handle_chunk(socket, chunk) do
    buffer = socket.assigns.stream_buffer <> chunk

    socket
    |> assign(:stream_buffer, buffer)
    |> push_event("scroll_to_bottom", %{})
  end

  defp handle_done(socket, content) do
    {:ok, document_context} = Agents.prepare_chat_context(socket.assigns)

    # Save assistant message to database if we have a session
    if socket.assigns.current_session_id do
      Agents.save_message(%{
        chat_session_id: socket.assigns.current_session_id,
        role: "assistant",
        content: content
      })
    end

    assistant_message = %{
      role: "assistant",
      content: content,
      timestamp: DateTime.utc_now(),
      source: document_context[:document_info]
    }

    # Send for test assertions
    send(self(), {:assistant_response, content})

    socket
    |> assign(:messages, socket.assigns.messages ++ [assistant_message])
    |> assign(:streaming, false)
    |> assign(:stream_buffer, "")
    |> push_event("scroll_to_bottom", %{})
  end

  defp handle_error(socket, error) do
    socket
    |> assign(:streaming, false)
    |> assign(:stream_buffer, "")
    |> assign(:error, "Error: #{error}")
  end

  @impl true
  def handle_event("toggle_panel", _params, socket) do
    collapsed = !socket.assigns.collapsed

    {:noreply, assign(socket, :collapsed, collapsed)}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  @impl true
  def handle_event("submit_on_enter", %{"key" => "Enter", "shiftKey" => true}, socket) do
    # Shift+Enter: allow default behavior (new line)
    {:noreply, socket}
  end

  def handle_event("submit_on_enter", %{"key" => "Enter"}, socket) do
    # Enter without Shift: submit form if message is not empty
    if String.trim(socket.assigns.current_message) != "" do
      handle_event("send_message", %{"message" => socket.assigns.current_message}, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_agent", %{"agent_id" => agent_id}, socket) do
    # Save selection to user preferences (database)
    workspace_id = get_nested(socket.assigns, [:current_workspace, :id])
    current_user = get_nested(socket.assigns, [:current_user])

    if workspace_id && current_user do
      Jarga.Accounts.set_selected_agent_id(current_user.id, workspace_id, agent_id)
    end

    {:noreply, assign(socket, :selected_agent_id, agent_id)}
  end

  @impl true
  def handle_event("restore_session", %{"session_id" => session_id}, socket)
      when session_id != "" do
    current_user_id = get_nested(socket.assigns, [:current_user, :id])

    with {:ok, session} <- Agents.load_session(session_id),
         :ok <- verify_session_ownership(session, current_user_id) do
      ui_messages = convert_messages_to_ui_format(session.messages)

      {:noreply,
       socket
       |> assign(:current_session_id, session.id)
       |> assign(:messages, ui_messages)}
    else
      {:error, :not_found} ->
        {:noreply, push_event(socket, "clear_session", %{})}

      {:error, :unauthorized} ->
        {:noreply, socket}
    end
  end

  def handle_event("restore_session", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", params, socket) do
    message_text = extract_message_text(params)

    if message_text == "" do
      {:noreply, socket}
    else
      socket
      |> process_message(message_text)
      |> send_chat_response()
    end
  end

  @impl true
  def handle_event("clear_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:stream_buffer, "")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:stream_buffer, "")
     |> assign(:error, nil)
     |> assign(:current_session_id, nil)
     |> assign(:view_mode, :chat)}
  end

  @impl true
  def handle_event("show_conversations", _params, socket) do
    user_id = get_nested(socket.assigns, [:current_user, :id])

    socket =
      if user_id do
        case Agents.list_sessions(user_id, limit: 20) do
          {:ok, sessions} ->
            socket
            |> assign(:view_mode, :conversations)
            |> assign(:sessions, sessions)

          {:error, _} ->
            socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_chat", _params, socket) do
    {:noreply, assign(socket, :view_mode, :chat)}
  end

  @impl true
  def handle_event("load_session", %{"session-id" => session_id}, socket) do
    current_user_id = get_nested(socket.assigns, [:current_user, :id])

    with {:ok, session} <- Agents.load_session(session_id),
         :ok <- verify_session_ownership(session, current_user_id) do
      ui_messages = convert_messages_to_ui_format(session.messages)

      {:noreply,
       socket
       |> assign(:current_session_id, session.id)
       |> assign(:messages, ui_messages)
       |> assign(:view_mode, :chat)
       |> push_event("save_session", %{session_id: session.id})}
    else
      _error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_session", %{"session-id" => session_id}, socket) do
    user_id = get_nested(socket.assigns, [:current_user, :id])

    socket =
      case delete_and_refresh_sessions(session_id, user_id, socket) do
        {:ok, updated_socket} -> updated_socket
        {:error, _} -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("insert_into_note", %{"content" => content}, socket) do
    # Validate content is not empty
    if String.trim(content) != "" do
      {:noreply, push_event(socket, "insert-text", %{content: content})}
    else
      {:noreply, socket}
    end
  end

  # Private helper functions

  defp verify_session_ownership(session, current_user_id) do
    if session.user_id == current_user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp convert_messages_to_ui_format(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: msg.role,
        content: msg.content,
        timestamp: msg.inserted_at
      }
    end)
  end

  defp delete_and_refresh_sessions(_session_id, nil, _socket) do
    {:error, :no_user}
  end

  defp delete_and_refresh_sessions(session_id, user_id, socket) do
    with {:ok, _deleted_session} <- Agents.delete_session(session_id, user_id),
         {:ok, sessions} <- Agents.list_sessions(user_id, limit: 20) do
      updated_socket =
        socket
        |> clear_session_if_active(session_id)
        |> assign(:sessions, sessions)

      {:ok, updated_socket}
    end
  end

  defp clear_session_if_active(socket, session_id) do
    if socket.assigns.current_session_id == session_id do
      socket
      |> assign(:current_session_id, nil)
      |> assign(:messages, [])
      |> push_event("clear_session", %{})
    else
      socket
    end
  end

  defp ensure_session(socket, first_message) do
    case socket.assigns.current_session_id do
      nil ->
        # Create new session
        user_id = get_nested(socket.assigns, [:current_user, :id])

        if user_id do
          {:ok, session} =
            Agents.create_session(%{
              user_id: user_id,
              workspace_id: get_nested(socket.assigns, [:current_workspace, :id]),
              project_id: get_nested(socket.assigns, [:current_project, :id]),
              first_message: first_message
            })

          assign(socket, :current_session_id, session.id)
        else
          # No user, can't create session
          socket
        end

      _session_id ->
        # Session already exists
        socket
    end
  end

  defp get_nested(data, [key]) when is_map(data) do
    Map.get(data, key)
  end

  defp get_nested(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      value when is_map(value) -> get_nested(value, rest)
      _ -> nil
    end
  end

  defp get_nested(_, _), do: nil

  # Determines if insert link should be shown based on context
  # Only show when on a document with a note attached
  defp should_show_insert?(assigns) do
    Map.has_key?(assigns, :document) && !is_nil(assigns[:document]) &&
      Map.has_key?(assigns, :note) && !is_nil(assigns[:note])
  end

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3_600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3_600)}h ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86_400)}d ago"
      true -> "#{div(diff_seconds, 604_800)}w ago"
    end
  end

  # Finds the selected agent from workspace_agents by selected_agent_id
  defp find_selected_agent(assigns) do
    selected_agent_id = Map.get(assigns, :selected_agent_id)
    workspace_agents = Map.get(assigns, :workspace_agents, [])

    if selected_agent_id do
      Enum.find(workspace_agents, fn agent -> agent.id == selected_agent_id end)
    else
      nil
    end
  end

  # Extracts message text from params
  defp extract_message_text(params) do
    case params do
      %{"message" => %{"content" => content}} -> String.trim(content)
      %{"message" => content} when is_binary(content) -> String.trim(content)
      _ -> ""
    end
  end

  # Processes user message and prepares socket for streaming
  defp process_message(socket, message_text) do
    # Get or create session
    socket = ensure_session(socket, message_text)

    # Save user message to database
    {:ok, _saved_user_msg} =
      Agents.save_message(%{
        chat_session_id: socket.assigns.current_session_id,
        role: "user",
        content: message_text
      })

    # Add user message to UI
    user_message = %{
      role: "user",
      content: message_text,
      timestamp: DateTime.utc_now()
    }

    # Get selected agent and prepare messages
    selected_agent = find_selected_agent(socket.assigns)
    {:ok, document_context} = Agents.prepare_chat_context(socket.assigns)
    {:ok, system_message} = build_system_message(selected_agent, document_context)

    updated_messages = socket.assigns.messages ++ [user_message]
    llm_messages = [system_message | updated_messages]
    llm_opts = build_llm_options(selected_agent)

    socket
    |> assign(:messages, updated_messages)
    |> assign(:current_message, "")
    |> assign(:streaming, true)
    |> assign(:stream_buffer, "")
    |> assign(:error, nil)
    |> assign(:llm_messages, llm_messages)
    |> assign(:llm_opts, llm_opts)
  end

  # Builds system message based on agent configuration
  defp build_system_message(selected_agent, document_context) do
    if selected_agent && selected_agent.system_prompt && selected_agent.system_prompt != "" do
      {:ok, %{role: "system", content: selected_agent.system_prompt}}
    else
      Agents.build_system_message(document_context)
    end
  end

  # Builds LLM options based on agent configuration
  defp build_llm_options(selected_agent) do
    []
    |> maybe_add_model(selected_agent)
    |> maybe_add_temperature(selected_agent)
  end

  defp maybe_add_model(opts, selected_agent) do
    if selected_agent && selected_agent.model && selected_agent.model != "" do
      Keyword.put(opts, :model, selected_agent.model)
    else
      opts
    end
  end

  defp maybe_add_temperature(opts, selected_agent) do
    if selected_agent && selected_agent.temperature do
      Keyword.put(opts, :temperature, selected_agent.temperature)
    else
      opts
    end
  end

  # Sends chat response via streaming
  defp send_chat_response(socket) do
    llm_messages = socket.assigns.llm_messages
    llm_opts = socket.assigns.llm_opts

    case Agents.chat_stream(llm_messages, self(), llm_opts) do
      {:ok, _pid} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:streaming, false)
         |> assign(:error, reason)}
    end
  end
end
