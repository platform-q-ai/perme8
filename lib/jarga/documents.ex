defmodule Jarga.Documents do
  @moduledoc """
  The Documents context.

  Handles document management, processing, and AI-powered chat functionality.
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Projects, Jarga.Repo],
    exports: [
      Infrastructure.Services.LlmClient,
      UseCases.PrepareContext,
      UseCases.CreateSession,
      UseCases.SaveMessage,
      UseCases.LoadSession,
      UseCases.ListSessions,
      UseCases.DeleteSession,
      ChatSession,
      ChatMessage
    ]

  alias Jarga.Documents.Infrastructure.Services.LlmClient
  alias Jarga.Documents.UseCases.{PrepareContext, CreateSession, SaveMessage, LoadSession, ListSessions, DeleteSession}

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

  @doc """
  Creates a new chat session.

  ## Examples

      iex> create_session(%{user_id: user.id})
      {:ok, %ChatSession{}}

  """
  defdelegate create_session(attrs), to: CreateSession, as: :execute

  @doc """
  Saves a message to a chat session.

  ## Examples

      iex> save_message(%{chat_session_id: session.id, role: "user", content: "Hello"})
      {:ok, %ChatMessage{}}

  """
  defdelegate save_message(attrs), to: SaveMessage, as: :execute

  @doc """
  Loads a chat session with its messages.

  ## Examples

      iex> load_session(session_id)
      {:ok, %ChatSession{messages: [...]}}

  """
  defdelegate load_session(session_id), to: LoadSession, as: :execute

  @doc """
  Lists chat sessions for a user.

  ## Examples

      iex> list_sessions(user_id)
      {:ok, [%{id: ..., title: "...", message_count: 5}]}

  """
  defdelegate list_sessions(user_id, opts \\ []), to: ListSessions, as: :execute

  @doc """
  Deletes a chat session.

  ## Examples

      iex> delete_session(session_id, user_id)
      {:ok, %ChatSession{}}

  """
  defdelegate delete_session(session_id, user_id), to: DeleteSession, as: :execute
end
