defmodule Jarga.Documents.UseCases.AIQuery do
  @moduledoc """
  Execute AI query within editor context and stream response.

  This use case handles in-editor AI requests by:
  - Extracting page context from assigns
  - Building contextualized system message
  - Streaming LLM response to caller process

  ## Examples

      iex> params = %{
      ...>   question: "How do I structure a Phoenix context?",
      ...>   assigns: socket.assigns
      ...> }
      iex> AIQuery.execute(params, self())
      {:ok, #PID<0.123.0>}

      # Then receive messages:
      receive do
        {:chunk, text} -> IO.puts(text)
        {:done, full_response} -> IO.puts("Complete: " <> full_response)
        {:error, reason} -> IO.puts("Error: " <> inspect(reason))
      end
  """

  alias Jarga.Documents.Infrastructure.Services.LlmClient

  @max_content_chars 3000

  @doc """
  Executes an AI query with page context.

  ## Parameters
    - params: Map with required keys:
      - :question - The user's question
      - :assigns - LiveView assigns containing page context
      - :node_id (optional) - Node ID for tracking
    - caller_pid: Process to receive streaming chunks

  ## Returns
    {:ok, pid} - Streaming process PID
    {:error, reason} - Error reason
  """
  def execute(params, caller_pid) do
    question = Map.fetch!(params, :question)
    assigns = Map.fetch!(params, :assigns)
    node_id = Map.get(params, :node_id)

    # Extract page context
    context = extract_context(assigns)

    # Build contextualized messages
    messages = build_messages(question, context)

    # Start streaming process that wraps LlmClient
    pid =
      spawn_link(fn ->
        handle_streaming(messages, caller_pid, node_id)
      end)

    {:ok, pid}
  end

  defp handle_streaming(messages, caller_pid, node_id) do
    # Set node_id in process dictionary for tracking
    if node_id do
      Process.put(:ai_node_id, node_id)
    end

    # Call LlmClient to start streaming
    case LlmClient.chat_stream(messages, self()) do
      {:ok, _stream_pid} ->
        # Forward messages from LlmClient to caller
        forward_stream(caller_pid, node_id)

      {:error, reason} ->
        # Send error to caller
        if node_id do
          send(caller_pid, {:ai_error, node_id, reason})
        else
          send(caller_pid, {:error, reason})
        end
    end
  end

  defp forward_stream(caller_pid, node_id) do
    receive do
      {:chunk, chunk} ->
        if node_id do
          send(caller_pid, {:ai_chunk, node_id, chunk})
        else
          send(caller_pid, {:chunk, chunk})
        end

        # Continue forwarding
        forward_stream(caller_pid, node_id)

      {:done, full_response} ->
        if node_id do
          send(caller_pid, {:ai_done, node_id, full_response})
        else
          send(caller_pid, {:done, full_response})
        end

      {:error, reason} ->
        if node_id do
          send(caller_pid, {:ai_error, node_id, reason})
        else
          send(caller_pid, {:error, reason})
        end
    after
      # Timeout after 60 seconds
      60_000 ->
        error = "AI query timed out after 60 seconds"

        if node_id do
          send(caller_pid, {:ai_error, node_id, error})
        else
          send(caller_pid, {:error, error})
        end
    end
  end

  defp extract_context(assigns) do
    %{
      workspace_name: get_workspace_name(assigns),
      project_name: get_project_name(assigns),
      page_title: get_page_title(assigns),
      page_content: get_page_content(assigns)
    }
  end

  defp get_workspace_name(assigns) do
    case Map.get(assigns, :current_workspace) do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp get_project_name(assigns) do
    case Map.get(assigns, :current_project) do
      %{name: name} -> name
      _ -> nil
    end
  end

  defp get_page_title(assigns) do
    Map.get(assigns, :page_title)
  end

  defp get_page_content(assigns) do
    case Map.get(assigns, :note) do
      %{note_content: %{"markdown" => markdown}} when is_binary(markdown) ->
        # Truncate to max chars to avoid huge context
        String.slice(markdown, 0, @max_content_chars)

      _ ->
        nil
    end
  end

  defp build_messages(question, context) do
    system_message = build_system_message(context)
    user_message = %{role: "user", content: question}

    [system_message, user_message]
  end

  defp build_system_message(context) do
    base_prompt = """
    You are an AI assistant helping within a note-taking editor.
    Provide concise, helpful responses in markdown format.
    Keep responses brief and actionable.
    """

    context_text = build_context_text(context)

    content =
      if String.trim(context_text) == "" do
        base_prompt
      else
        base_prompt <> "\n\nCurrent context:\n" <> context_text
      end

    %{role: "system", content: content}
  end

  defp build_context_text(context) do
    context_parts = []

    context_parts =
      if context[:workspace_name] do
        context_parts ++ ["Workspace: #{context.workspace_name}"]
      else
        context_parts
      end

    context_parts =
      if context[:project_name] do
        context_parts ++ ["Project: #{context.project_name}"]
      else
        context_parts
      end

    context_parts =
      if context[:page_title] do
        context_parts ++ ["Page: #{context.page_title}"]
      else
        context_parts
      end

    context_parts =
      if context[:page_content] do
        # Truncate preview of content
        preview =
          context.page_content
          |> String.slice(0, 500)
          |> String.trim()

        context_parts ++ ["Page content preview:\n#{preview}..."]
      else
        context_parts
      end

    Enum.join(context_parts, "\n")
  end
end
