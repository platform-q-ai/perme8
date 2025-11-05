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
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:page_context, fn -> extract_page_context(assigns) end)

    # Handle streaming messages sent via send_update from parent
    socket =
      cond do
        Map.has_key?(assigns, :chunk) ->
          buffer = socket.assigns.stream_buffer <> assigns.chunk

          socket
          |> assign(:stream_buffer, buffer)
          |> push_event("scroll_to_bottom", %{})

        Map.has_key?(assigns, :done) ->
          # Add assistant message with source attribution
          assistant_message = %{
            role: "assistant",
            content: assigns.done,
            timestamp: DateTime.utc_now(),
            source: socket.assigns[:page_context][:page_info]
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

  # Private functions

  defp extract_page_context(assigns) do
    # Extract page content if viewing a page
    page_content = extract_page_content(assigns)

    # Extract page information for source citation
    page_info = extract_page_info(assigns)

    %{
      current_user: get_nested(assigns, [:current_user, :email]),
      current_workspace: get_nested(assigns, [:current_workspace, :name]),
      current_project: get_nested(assigns, [:current_project, :name]),
      page_title: assigns[:page_title],
      page_content: page_content,
      page_info: page_info,
      # Additional context can be extracted from assigns
      # This is a simple implementation for PR #1
      assigns: Map.drop(assigns, [:socket, :flash, :myself])
    }
  end

  defp extract_page_content(assigns) do
    # Check if we have a note (page content)
    case get_nested(assigns, [:note, :note_content]) do
      %{"markdown" => markdown} when is_binary(markdown) and markdown != "" ->
        # Limit content to avoid token limits (first 3000 characters)
        String.slice(markdown, 0, 3000)

      _ ->
        nil
    end
  end

  defp extract_page_info(assigns) do
    # Extract page metadata for source citations
    workspace_slug = get_nested(assigns, [:current_workspace, :slug])
    page_slug = get_nested(assigns, [:page, :slug])
    page_title = assigns[:page_title]

    # Build the page URL if we have the necessary information
    page_url =
      if workspace_slug && page_slug do
        ~p"/app/workspaces/#{workspace_slug}/pages/#{page_slug}"
      else
        nil
      end

    if page_url && page_title do
      %{
        page_title: page_title,
        page_url: page_url
      }
    else
      nil
    end
  end

  defp get_nested(data, [key]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      %{} = struct -> Map.get(struct, key)
      value -> value
    end
  end

  defp get_nested(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      %{__struct__: _} = struct -> get_nested(struct, rest)
      map when is_map(map) -> get_nested(map, rest)
      _ -> nil
    end
  end

  defp get_nested(_, _), do: nil

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

    context_parts =
      if page_context.page_content do
        context_parts ++ ["Page content:\n#{page_context.page_content}"]
      else
        context_parts
      end

    if Enum.empty?(context_parts) do
      %{
        role: "system",
        content: "You are a helpful assistant. Answer questions based on the context provided."
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
