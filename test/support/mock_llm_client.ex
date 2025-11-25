defmodule Jarga.Test.Support.MockLlmClient do
  @moduledoc """
  Mock LLM client for E2E tests.

  Provides deterministic, fast responses for Wallaby tests without requiring real API calls.
  Implements the same interface as the real LlmClient without explicit behaviour declaration
  (to avoid boundary violations in test support code).

  ## Usage

  Configure in config/test.exs:

      config :jarga, :llm_client, Jarga.Test.Support.MockLlmClient

  ## Responses

  The mock provides predefined responses based on agent name patterns:
  - "prd" → Returns PRD explanation
  - "invalid" or "nonexistent" → Returns error message
  - Default → Returns generic helpful response

  ## Interface

  This module implements the same interface as Jarga.Agents.Application.Services.LlmClient:
  - chat/2 - Returns immediate response
  - chat_stream/3 - Sends chunks to simulate streaming
  """

  @doc """
  Mock implementation of chat/2.
  Returns immediate responses without API calls.
  """
  @spec chat(list(map()), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def chat(messages, _opts \\ []) do
    # Extract user question from messages
    user_message = Enum.find(messages, fn msg -> msg[:role] == "user" end)
    question = if user_message, do: user_message[:content], else: ""

    # Determine agent from system message or default
    system_message = Enum.find(messages, fn msg -> msg[:role] == "system" end)
    agent_hint = if system_message, do: system_message[:content], else: ""

    response = generate_mock_response(question, agent_hint)
    {:ok, response}
  end

  @doc """
  Mock implementation of chat_stream/3.
  Sends predefined chunks to simulate streaming.
  """
  @spec chat_stream(list(map()), pid(), keyword()) :: {:ok, pid()} | {:error, String.t()}
  def chat_stream(messages, caller_pid, _opts \\ []) do
    # Extract user question from messages
    user_message = Enum.find(messages, fn msg -> msg[:role] == "user" end)
    question = if user_message, do: user_message[:content], else: ""

    # Determine agent from system message or default
    system_message = Enum.find(messages, fn msg -> msg[:role] == "system" end)
    agent_hint = if system_message, do: system_message[:content], else: ""

    # Spawn process to simulate streaming
    pid =
      spawn_link(fn ->
        simulate_streaming(question, agent_hint, caller_pid)
      end)

    {:ok, pid}
  end

  # Private functions

  defp generate_mock_response(question, agent_hint) do
    cond do
      # PRD agent responses
      contains_ignore_case?(agent_hint, "prd") or contains_ignore_case?(question, "prd") ->
        """
        A PRD (Product Requirements Document) is a comprehensive document that outlines the requirements, 
        goals, and specifications for a product or feature. It typically includes user stories, 
        acceptance criteria, technical constraints, and success metrics. PRDs serve as the single 
        source of truth for product development teams.
        """

      # Invalid/nonexistent agent
      contains_ignore_case?(question, "invalid") or contains_ignore_case?(question, "nonexistent") ->
        """
        The agent name you specified doesn't exist in this workspace. 
        Agent names should match existing agents you've created. 
        Check your agent list and try again with a valid agent name.
        """

      # Generic helpful response
      true ->
        """
        I'm here to help! Based on your question, I can provide assistance with your document. 
        Please let me know what specific information you need.
        """
    end
    |> String.trim()
  end

  defp simulate_streaming(question, agent_hint, caller_pid) do
    full_response = generate_mock_response(question, agent_hint)

    # Split response into chunks (simulating word-by-word streaming)
    chunks =
      full_response
      |> String.split(" ")
      |> Enum.map(&(&1 <> " "))

    # Send chunks with small delays
    Enum.each(chunks, fn chunk ->
      send(caller_pid, {:chunk, chunk})
      # 5ms delay between chunks (very fast for tests)
      Process.sleep(5)
    end)

    # Send final done message
    send(caller_pid, {:done, String.trim(full_response)})
  end

  defp contains_ignore_case?(text, pattern) when is_binary(text) and is_binary(pattern) do
    String.downcase(text) =~ String.downcase(pattern)
  end

  defp contains_ignore_case?(_, _), do: false
end
