defmodule Jarga.Chat do
  @moduledoc """
  The Chat context.

  Handles chat session and message management for AI-powered conversations.
  This context is separate from Agents, which handles AI agent configuration.

  ## Responsibilities
  - Chat session lifecycle (create, list, load, delete)
  - Chat message management (save, delete)
  - Context preparation for LLM prompts
  - System message building for conversations

  ## Error Types

  Standard error atoms returned by this context:

  - `:not_found` - Session/message not found or user doesn't have access
  - `:forbidden` - User is not authorized to perform this action
  - `:invalid_params` - Validation error (returns `{:error, changeset}`)

  ## Examples

      # Create a session
      {:ok, session} = Chat.create_session(%{user_id: user.id})

      # Save a message
      {:ok, message} = Chat.save_message(%{
        chat_session_id: session.id,
        role: "user",
        content: "Hello!"
      })

      # List sessions
      {:ok, sessions} = Chat.list_sessions(user_id)

      # Delete a session
      {:ok, session} = Chat.delete_session(session_id, user_id)
  """

  # Core context - cannot depend on JargaWeb (interface layer)
  # Exports: ONLY domain entities (Session, Message)
  # All use cases and infrastructure modules are PRIVATE - accessed only via public API functions
  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Chat.Domain,
      Jarga.Chat.Application,
      Jarga.Chat.Infrastructure,
      Jarga.Accounts,
      Jarga.Workspaces,
      Jarga.Projects,
      Jarga.Agents,
      Jarga.Repo
    ],
    exports: [
      {Domain.Entities.Session, []},
      {Domain.Entities.Message, []}
    ]

  # Import use cases
  alias Jarga.Chat.Application.UseCases.{
    PrepareContext,
    CreateSession,
    SaveMessage,
    DeleteMessage,
    LoadSession,
    ListSessions,
    DeleteSession
  }

  # Chat Context and Message Preparation

  @doc """
  Prepares chat context from LiveView assigns.

  Extracts relevant document information (workspace, project, content) and
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
  Builds a system message that combines an agent's custom prompt with document context.

  If the agent has a custom system_prompt, it combines it with document context.
  Otherwise, uses the default system message with context.

  ## Examples

      iex> agent = %{system_prompt: "You are a code reviewer."}
      iex> context = %{current_workspace: "ACME", document_content: "..."}
      iex> build_system_message_with_agent(agent, context)
      {:ok, %{role: "system", content: "You are a code reviewer.\\n\\nCurrent context:\\n..."}}

  """
  defdelegate build_system_message_with_agent(agent, context), to: PrepareContext

  # Session Management

  @doc """
  Creates a new chat session.

  ## Examples

      iex> create_session(%{user_id: user.id})
      {:ok, %Session{}}

  """
  defdelegate create_session(attrs), to: CreateSession, as: :execute

  @doc """
  Lists chat sessions for a user.

  ## Examples

      iex> list_sessions(user_id)
      {:ok, [%{id: ..., title: "...", message_count: 5}]}

  """
  defdelegate list_sessions(user_id, opts \\ []), to: ListSessions, as: :execute

  @doc """
  Loads a chat session with its messages.

  ## Examples

      iex> load_session(session_id)
      {:ok, %Session{messages: [...]}}

  """
  defdelegate load_session(session_id), to: LoadSession, as: :execute

  @doc """
  Deletes a chat session.

  ## Examples

      iex> delete_session(session_id, user_id)
      {:ok, %Session{}}

  """
  defdelegate delete_session(session_id, user_id), to: DeleteSession, as: :execute

  # Message Management

  @doc """
  Saves a message to a chat session.

  ## Examples

      iex> save_message(%{chat_session_id: session.id, role: "user", content: "Hello"})
      {:ok, %Message{}}

  """
  defdelegate save_message(attrs), to: SaveMessage, as: :execute

  @doc """
  Deletes a chat message by ID, verifying user ownership through the session.

  ## Examples

      iex> delete_message(message_id, user_id)
      {:ok, %Message{}}

      iex> delete_message(invalid_id, user_id)
      {:error, :not_found}

  """
  defdelegate delete_message(message_id, user_id), to: DeleteMessage, as: :execute
end
