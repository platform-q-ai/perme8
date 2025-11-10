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
      UseCases.AIQuery,
      UseCases.CreateSession,
      UseCases.SaveMessage,
      UseCases.LoadSession,
      UseCases.ListSessions,
      UseCases.DeleteSession,
      ChatSession,
      ChatMessage
    ]

  alias Jarga.Documents.Infrastructure.Services.LlmClient

  alias Jarga.Documents.UseCases.{
    PrepareContext,
    AIQuery,
    CreateSession,
    SaveMessage,
    LoadSession,
    ListSessions,
    DeleteSession
  }

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

  @doc """
  Executes an AI query with page context and streams response.

  This is used for in-editor AI assistance. The AI response is streamed
  to the caller process as chunks.

  ## Parameters
    - params: Map with required keys:
      - :question - The user's question
      - :assigns - LiveView assigns containing page context
      - :node_id (optional) - Node ID for tracking in the editor
    - caller_pid: Process to receive streaming chunks

  ## Examples

      iex> params = %{
      ...>   question: "How do I structure a Phoenix context?",
      ...>   assigns: socket.assigns,
      ...>   node_id: "ai_node_123"
      ...> }
      iex> ai_query(params, self())
      {:ok, #PID<0.123.0>}

      # Then receive messages:
      receive do
        {:ai_chunk, node_id, chunk} -> IO.puts(chunk)
        {:ai_done, node_id, response} -> IO.puts("Complete!")
        {:ai_error, node_id, reason} -> IO.puts("Error: " <> reason)
      end

  """
  defdelegate ai_query(params, caller_pid), to: AIQuery, as: :execute

  @doc """
  Cancels an active AI query.

  Terminates the streaming process for the given node_id.

  ## Parameters
    - query_pid: Process PID returned from ai_query/2
    - node_id: Node ID for the query

  ## Examples

      iex> {:ok, pid} = Documents.ai_query(params, self())
      iex> Documents.cancel_ai_query(pid, "node_123")
      :ok

  """
  @spec cancel_ai_query(pid(), String.t()) :: :ok
  def cancel_ai_query(query_pid, node_id) when is_pid(query_pid) and is_binary(node_id) do
    # Send cancel signal to the query process
    send(query_pid, {:cancel, node_id})
    :ok
  end
end
