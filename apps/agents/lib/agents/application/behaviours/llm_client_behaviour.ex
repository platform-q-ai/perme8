defmodule Agents.Application.Behaviours.LlmClientBehaviour do
  @moduledoc """
  Behaviour for LLM client implementations.

  Defines the contract for both synchronous and streaming LLM interactions,
  allowing mock implementations in tests via Mox.
  """

  @callback chat(messages :: list(map()), opts :: keyword()) ::
              {:ok, String.t()} | {:error, String.t()}

  @callback chat_stream(messages :: list(map()), caller_pid :: pid(), opts :: keyword()) ::
              {:ok, pid()} | {:error, String.t()}
end
