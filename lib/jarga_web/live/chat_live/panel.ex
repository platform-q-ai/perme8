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
     |> assign(:error, nil)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:page_context, fn -> extract_page_context(assigns) end)}
  end

  @impl true
  def handle_event("toggle_panel", _params, socket) do
    collapsed = !socket.assigns.collapsed

    # Notify JS hook to save state
    {:noreply,
     socket
     |> assign(:collapsed, collapsed)
     |> push_event("save_state", %{collapsed: collapsed})}
  end

  @impl true
  def handle_event("restore_state", %{"collapsed" => collapsed}, socket) do
    {:noreply, assign(socket, :collapsed, collapsed)}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_text}, socket) do
    message_text = String.trim(message_text)

    if message_text == "" do
      {:noreply, socket}
    else
      # Add user message
      user_message = %{
        role: "user",
        content: message_text,
        timestamp: DateTime.utc_now()
      }

      socket =
        socket
        |> assign(:messages, socket.assigns.messages ++ [user_message])
        |> assign(:current_message, "")
        |> assign(:streaming, true)
        |> assign(:stream_buffer, "")
        |> assign(:error, nil)

      # Build context from page
      context = build_context_message(socket.assigns.page_context)

      # Prepare messages for LLM
      llm_messages =
        if context do
          [context | socket.assigns.messages]
        else
          socket.assigns.messages
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
  def handle_info({:chunk, chunk}, socket) do
    buffer = socket.assigns.stream_buffer <> chunk

    {:noreply,
     socket
     |> assign(:stream_buffer, buffer)
     |> push_event("scroll_to_bottom", %{})}
  end

  @impl true
  def handle_info({:done, full_response}, socket) do
    # Add assistant message
    assistant_message = %{
      role: "assistant",
      content: full_response,
      timestamp: DateTime.utc_now()
    }

    # Send for test assertions
    send(self(), {:assistant_response, full_response})

    {:noreply,
     socket
     |> assign(:messages, socket.assigns.messages ++ [assistant_message])
     |> assign(:streaming, false)
     |> assign(:stream_buffer, "")
     |> push_event("scroll_to_bottom", %{})}
  end

  @impl true
  def handle_info({:error, reason}, socket) do
    {:noreply,
     socket
     |> assign(:streaming, false)
     |> assign(:stream_buffer, "")
     |> assign(:error, "Error: #{reason}")}
  end

  # Private functions

  defp extract_page_context(assigns) do
    %{
      current_user: get_in(assigns, [:current_user, :email]),
      current_workspace: get_in(assigns, [:current_workspace, :name]),
      current_project: get_in(assigns, [:current_project, :name]),
      page_title: assigns[:page_title],
      # Additional context can be extracted from assigns
      # This is a simple implementation for PR #1
      assigns: Map.drop(assigns, [:socket, :flash, :myself])
    }
  end

  defp build_context_message(page_context) do
    context_parts = []

    context_parts =
      if page_context.current_workspace do
        context_parts ++
          ["You are viewing workspace: #{page_context.current_workspace}"]
      else
        context_parts
      end

    context_parts =
      if page_context.current_project do
        context_parts ++
          ["You are viewing project: #{page_context.current_project}"]
      else
        context_parts
      end

    context_parts =
      if page_context.page_title do
        context_parts ++ ["Page title: #{page_context.page_title}"]
      else
        context_parts
      end

    if Enum.empty?(context_parts) do
      %{
        role: "system",
        content:
          "You are a helpful assistant. Answer questions based on the context provided."
      }
    else
      context_text = Enum.join(context_parts, "\n")

      %{
        role: "system",
        content: """
        You are a helpful assistant for Jarga, a project management application.

        Current context:
        #{context_text}

        Answer questions based on the current page context. Be concise and helpful.
        """
      }
    end
  end

end
