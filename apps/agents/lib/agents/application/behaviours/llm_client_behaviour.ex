defmodule Agents.Application.Behaviours.LlmClientBehaviour do
  @moduledoc """
  Behaviour for LLM client implementations.

  This allows mocking LlmClient in tests for testing streaming functionality.
  """

  @callback chat_stream(messages :: list(map()), caller_pid :: pid(), opts :: keyword()) ::
              {:ok, pid()} | {:error, String.t()}
end
