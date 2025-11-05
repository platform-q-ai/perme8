defmodule Jarga.Documents do
  @moduledoc """
  The Documents context.

  Handles document management, processing, and AI-powered chat functionality.
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Repo],
    exports: [Infrastructure.Services.LlmClient, UseCases.PrepareContext]

  alias Jarga.Documents.Infrastructure.Services.LlmClient
  alias Jarga.Documents.UseCases.PrepareContext

  @doc """
  Prepares chat context from LiveView assigns.

  Extracts relevant page information (workspace, project, content) and
  formats it for use in chat interactions.

  ## Examples

      iex> prepare_chat_context(%{current_workspace: %{name: "ACME"}})
      {:ok, %{current_workspace: "ACME", ...}}

  """
  defdelegate prepare_chat_context(assigns), to: PrepareContext, as: :execute

  @doc """
  Builds a system message for the LLM from extracted context.

  ## Examples

      iex> build_system_message(%{current_workspace: "ACME"})
      {:ok, %{role: "system", content: "..."}}

  """
  defdelegate build_system_message(context), to: PrepareContext

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
