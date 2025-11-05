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
      # Add user message
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

end
