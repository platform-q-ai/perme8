defmodule Jarga.Documents do
  @moduledoc """
  The Documents context.

  Handles document management, processing, and AI-powered chat functionality.
  """

  use Boundary,
    deps: [Jarga.Accounts],
    exports: [Infrastructure.Services.LlmClient]

  alias Jarga.Documents.Infrastructure.Services.LlmClient

  @doc """
  Sends a chat completion request to the LLM.

  ## Examples

      iex> chat([%{role: "user", content: "Hello!"}])
      {:ok, "Hello! How can I help you?"}

  """
  defdelegate chat(messages, opts \\ []), to: LlmClient

  @doc """
  Streams a chat completion response in chunks.

  ## Examples

      iex> {:ok, _pid} = chat_stream(messages, self())
      iex> receive do
      ...>   {:chunk, text} -> IO.puts(text)
      ...> end

  """
  defdelegate chat_stream(messages, caller_pid, opts \\ []), to: LlmClient
end
