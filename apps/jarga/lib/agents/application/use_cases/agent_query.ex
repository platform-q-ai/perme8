defmodule Jarga.Agents.Application.UseCases.AgentQuery do
  @moduledoc """
  Execute agent query within editor context and stream response.

  This use case handles in-editor agent requests by:
  - Extracting document context from assigns
  - Building contextualized system message (with optional agent-specific prompt)
  - Applying agent-specific settings (model, temperature)
  - Streaming LLM response to caller process

  ## Agent-Specific Settings

  When an `agent` is provided in params, the use case will:
  - Use the agent's `system_prompt` instead of the default prompt
  - Pass the agent's `model` to the LLM client
  - Pass the agent's `temperature` to the LLM client
  - Combine the agent's prompt with document context

  ## Examples

      # Without agent (uses default settings)
      iex> params = %{
      ...>   question: "How do I structure a Phoenix context?",
      ...>   assigns: socket.assigns
      ...> }
      iex> AgentQuery.execute(params, self())
      {:ok, #PID<0.123.0>}

      # With agent (uses agent-specific settings)
      iex> params = %{
      ...>   question: "How do I structure a Phoenix context?",
      ...>   agent: %{system_prompt: "You are a Phoenix expert", model: "gpt-4", temperature: 0.7},
      ...>   assigns: socket.assigns
      ...> }
      iex> AgentQuery.execute(params, self())
      {:ok, #PID<0.123.0>}

      # Then receive messages:
      receive do
        {:chunk, text} -> IO.puts(text)
        {:done, full_response} -> IO.puts("Complete: " <> full_response)
        {:error, reason} -> IO.puts("Error: " <> inspect(reason))
      end
  """

  alias Jarga.Agents.Infrastructure.Services.LlmClient

  @max_content_chars 3000

  @doc """
  Executes an agent query with document context.

  ## Parameters
    - params: Map with required keys:
      - :question - The user's question
      - :assigns - LiveView assigns containing document context
      - :agent (optional) - Agent struct with custom settings (system_prompt, model, temperature)
      - :node_id (optional) - Node ID for tracking
      - :llm_client (optional) - LLM client module for dependency injection (default: LlmClient)
    - caller_pid: Process to receive streaming chunks

  ## Returns
    {:ok, pid} - Streaming process PID
    {:error, reason} - Error reason
  """
  def execute(params, caller_pid) do
    question = Map.fetch!(params, :question)
    assigns = Map.fetch!(params, :assigns)
    agent = Map.get(params, :agent)
    node_id = Map.get(params, :node_id)
    # Allow dependency injection via params with sensible default
    llm_client = Map.get(params, :llm_client, LlmClient)

    # Extract document context
    context = extract_context(assigns)

    # Build contextualized messages with agent-specific settings
    messages = build_messages(question, context, agent)

    # Prepare LLM client options with agent settings
    opts = build_llm_opts(agent)

    # Start streaming process that wraps LlmClient
    pid =
      spawn_link(fn ->
        handle_streaming(messages, caller_pid, node_id, llm_client, opts)
      end)

    {:ok, pid}
  end

  defp handle_streaming(messages, caller_pid, node_id, llm_client, opts) do
    # Set node_id in process dictionary for tracking
    if node_id do
      Process.put(:agent_node_id, node_id)
    end

    # Call LlmClient to start streaming with agent-specific opts
    case llm_client.chat_stream(messages, self(), opts) do
      {:ok, _stream_pid} ->
        # Forward messages from LlmClient to caller
        forward_stream(caller_pid, node_id)

      {:error, reason} ->
        # Send error to caller
        if node_id do
          send(caller_pid, {:agent_error, node_id, reason})
        else
          send(caller_pid, {:error, reason})
        end
    end
  end

  defp forward_stream(caller_pid, node_id) do
    receive do
      # Handle cancellation request
      {:cancel, ^node_id} ->
        error = "Query cancelled by user"

        if node_id do
          send(caller_pid, {:agent_error, node_id, error})
        else
          send(caller_pid, {:error, error})
        end

        # Exit gracefully after sending error
        :ok

      {:chunk, chunk} ->
        if node_id do
          send(caller_pid, {:agent_chunk, node_id, chunk})
        else
          send(caller_pid, {:chunk, chunk})
        end

        # Continue forwarding
        forward_stream(caller_pid, node_id)

      {:done, full_response} ->
        if node_id do
          send(caller_pid, {:agent_done, node_id, full_response})
        else
          send(caller_pid, {:done, full_response})
        end

      {:error, reason} ->
        if node_id do
          send(caller_pid, {:agent_error, node_id, reason})
        else
          send(caller_pid, {:error, reason})
        end
    after
      # Timeout after 60 seconds
      60_000 ->
        error = "Agent query timed out after 60 seconds"

        if node_id do
          send(caller_pid, {:agent_error, node_id, error})
        else
          send(caller_pid, {:error, error})
        end
    end
  end

  defp extract_context(assigns) do
    %{
      workspace_name: get_workspace_name(assigns),
      project_name: get_project_name(assigns),
      document_title: get_document_title(assigns),
      document_content: get_document_content(assigns)
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

  defp get_document_title(assigns) do
    Map.get(assigns, :document_title)
  end

  defp get_document_content(assigns) do
    # note_content is now plain text markdown
    case Map.get(assigns, :note) do
      %{note_content: content} when is_binary(content) and content != "" ->
        # Truncate to max chars to avoid huge context
        String.slice(content, 0, @max_content_chars)

      _ ->
        nil
    end
  end

  defp build_messages(question, context, agent) do
    system_message = build_system_message(context, agent)
    user_message = %{role: "user", content: question}

    [system_message, user_message]
  end

  defp build_system_message(context, agent) do
    # Use agent's custom system_prompt if provided, otherwise use default
    base_prompt =
      case get_agent_system_prompt(agent) do
        prompt when is_binary(prompt) and prompt != "" ->
          prompt

        _ ->
          """
          You are an agent assistant helping within a note-taking editor.
          Provide concise, helpful responses in markdown format.
          Keep responses brief and actionable.
          """
      end

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
      if context[:document_title] do
        context_parts ++ ["Document: #{context.document_title}"]
      else
        context_parts
      end

    context_parts =
      if context[:document_content] do
        # Truncate preview of content
        preview =
          context.document_content
          |> String.slice(0, 500)
          |> String.trim()

        context_parts ++ ["Document content preview:\n#{preview}..."]
      else
        context_parts
      end

    Enum.join(context_parts, "\n")
  end

  # Build LLM client options from agent settings
  # Returns keyword list with :model and :temperature if provided by agent
  defp build_llm_opts(nil), do: []

  defp build_llm_opts(agent) do
    []
    |> maybe_put_model(agent)
    |> maybe_put_temperature(agent)
  end

  defp maybe_put_model(opts, agent) do
    case get_agent_model(agent) do
      model when is_binary(model) and model != "" ->
        Keyword.put(opts, :model, model)

      _ ->
        opts
    end
  end

  defp maybe_put_temperature(opts, agent) do
    case get_agent_temperature(agent) do
      temp when is_number(temp) ->
        Keyword.put(opts, :temperature, temp)

      _ ->
        opts
    end
  end

  # Helper functions to safely extract agent fields (works with maps and structs)
  defp get_agent_system_prompt(nil), do: nil

  defp get_agent_system_prompt(agent) do
    prompt = Map.get(agent, :system_prompt)
    if is_binary(prompt), do: String.trim(prompt), else: nil
  end

  defp get_agent_model(nil), do: nil

  defp get_agent_model(agent) do
    model = Map.get(agent, :model)
    if is_binary(model), do: String.trim(model), else: nil
  end

  defp get_agent_temperature(nil), do: nil
  defp get_agent_temperature(agent), do: Map.get(agent, :temperature)
end
