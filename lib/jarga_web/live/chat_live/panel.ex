defmodule JargaWeb.ChatLive.Panel do
  @moduledoc """
  Global chat panel LiveView component.

  Provides an always-accessible chat interface that can be toggled from any page.
  In PR #1, this chats with the current page content.
  Future PRs will add document chat functionality.
  """
  use JargaWeb, :live_component

  import JargaWeb.ChatLive.Components.Message

  alias Jarga.Documents

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:collapsed, true)
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:streaming, false)
     |> assign(:stream_buffer, "")
     |> assign(:error, nil)
     |> assign(:current_session_id, nil)
     |> assign(:view_mode, :chat)
     |> assign(:sessions, [])}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Handle streaming messages sent via send_update from parent
    socket =
      cond do
        Map.has_key?(assigns, :chunk) ->
          buffer = socket.assigns.stream_buffer <> assigns.chunk

          socket
          |> assign(:stream_buffer, buffer)
          |> push_event("scroll_to_bottom", %{})

        Map.has_key?(assigns, :done) ->
          # Extract page info for source attribution
          {:ok, page_context} = Documents.prepare_chat_context(socket.assigns)

          # Save assistant message to database if we have a session
          if socket.assigns.current_session_id do
            {:ok, _saved_assistant_msg} =
              Documents.save_message(%{
                chat_session_id: socket.assigns.current_session_id,
                role: "assistant",
                content: assigns.done
              })
          end

          # Add assistant message with source attribution
          assistant_message = %{
            role: "assistant",
            content: assigns.done,
            timestamp: DateTime.utc_now(),
            source: page_context[:page_info]
          }

          # Send for test assertions
          send(self(), {:assistant_response, assigns.done})

          socket
          |> assign(:messages, socket.assigns.messages ++ [assistant_message])
          |> assign(:streaming, false)
          |> assign(:stream_buffer, "")
          |> push_event("scroll_to_bottom", %{})

        Map.has_key?(assigns, :error) ->
          socket
          |> assign(:streaming, false)
          |> assign(:stream_buffer, "")
          |> assign(:error, "Error: #{assigns.error}")

        true ->
          socket
      end

    {:ok, socket}
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
  def handle_event("restore_session", %{"session_id" => session_id}, socket)
      when session_id != "" do
    current_user_id = get_nested(socket.assigns, [:current_user, :id])

    with {:ok, session} <- Documents.load_session(session_id),
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
    message_text =
      case params do
        %{"message" => %{"content" => content}} -> String.trim(content)
        %{"message" => content} when is_binary(content) -> String.trim(content)
        _ -> ""
      end

    if message_text == "" do
      {:noreply, socket}
    else
      # Get or create session
      socket = ensure_session(socket, message_text)

      # Save user message to database
      {:ok, _saved_user_msg} =
        Documents.save_message(%{
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

      # Prepare context from current assigns using Documents context
      {:ok, page_context} = Documents.prepare_chat_context(socket.assigns)
      {:ok, system_message} = Documents.build_system_message(page_context)

      # Build updated message list
      updated_messages = socket.assigns.messages ++ [user_message]

      # Prepare messages for LLM (system message + conversation history)
      llm_messages = [system_message | updated_messages]

      socket =
        socket
        |> assign(:messages, updated_messages)
        |> assign(:current_message, "")
        |> assign(:streaming, true)
        |> assign(:stream_buffer, "")
        |> assign(:error, nil)

      # Push session_id to localStorage if this is a new session
      socket =
        if socket.assigns.current_session_id do
          push_event(socket, "save_session", %{session_id: socket.assigns.current_session_id})
        else
          socket
        end

      # Start streaming response
      case Documents.chat_stream(llm_messages, self()) do
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
     |> assign(:view_mode, :chat)
     |> push_event("clear_session", %{})}
  end

  @impl true
  def handle_event("show_conversations", _params, socket) do
    user_id = get_nested(socket.assigns, [:current_user, :id])

    socket =
      if user_id do
        case Documents.list_sessions(user_id, limit: 20) do
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

    with {:ok, session} <- Documents.load_session(session_id),
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
    with {:ok, _deleted_session} <- Documents.delete_session(session_id, user_id),
         {:ok, sessions} <- Documents.list_sessions(user_id, limit: 20) do
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
            Documents.create_session(%{
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
end
