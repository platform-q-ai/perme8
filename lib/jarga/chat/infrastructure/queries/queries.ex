defmodule Jarga.Chat.Infrastructure.Queries.Queries do
  @moduledoc """
  Query objects for the Chat context.

  This module follows Clean Architecture Infrastructure Layer principles:
  - Encapsulates all database query logic for chat sessions and messages
  - Provides composable query fragments
  - Returns Ecto queryables, not results
  - Used by repositories and use cases

  ## Design
  According to ARCHITECTURE.md, query objects:
  - Keep use cases focused on orchestration
  - Make queries reusable and testable
  - Separate data access from business logic
  """

  import Ecto.Query

  alias Jarga.Chat.Infrastructure.Schemas.{SessionSchema, MessageSchema}

  # ChatSession Queries

  @doc """
  Base query for chat sessions.
  """
  def session_base do
    from(s in SessionSchema)
  end

  @doc """
  Filters sessions by user ID.
  """
  def for_user(query \\ session_base(), user_id) do
    from(s in query, where: s.user_id == ^user_id)
  end

  @doc """
  Filters sessions by session ID and user ID (for authorization).
  """
  def by_id_and_user(query \\ session_base(), session_id, user_id) do
    from(s in query,
      where: s.id == ^session_id and s.user_id == ^user_id
    )
  end

  @doc """
  Filters sessions by session ID.
  """
  def by_id(query \\ session_base(), session_id) do
    from(s in query, where: s.id == ^session_id)
  end

  @doc """
  Preloads session relationships including messages.
  """
  def with_preloads(query \\ session_base()) do
    from(s in query,
      preload: [
        :user,
        :workspace,
        :project,
        messages: ^messages_ordered()
      ]
    )
  end

  @doc """
  Orders sessions by most recent first.
  Uses updated_at as primary sort, inserted_at as tiebreaker for consistent ordering.
  """
  def ordered_by_recent(query \\ session_base()) do
    from(s in query, order_by: [desc: s.updated_at, desc: s.inserted_at])
  end

  @doc """
  Limits the number of results.
  """
  def limit_results(query, limit) do
    from(q in query, limit: ^limit)
  end

  @doc """
  Joins sessions with messages and aggregates message count.

  Returns sessions with message_count field via group_by.
  """
  def with_message_count(query \\ session_base()) do
    from(s in query,
      left_join: m in assoc(s, :messages),
      group_by: s.id,
      select: %{
        id: s.id,
        title: s.title,
        inserted_at: s.inserted_at,
        updated_at: s.updated_at,
        message_count: count(m.id)
      }
    )
  end

  # ChatMessage Queries

  @doc """
  Base query for chat messages.
  """
  def message_base do
    from(m in MessageSchema)
  end

  @doc """
  Filters messages by session ID.
  """
  def for_session(query \\ message_base(), session_id) do
    from(m in query, where: m.chat_session_id == ^session_id)
  end

  @doc """
  Orders messages chronologically (oldest first).
  """
  def messages_ordered do
    from(m in MessageSchema, order_by: [asc: m.inserted_at])
  end

  @doc """
  Gets the first message for a session (for preview).
  """
  def first_message_content(session_id) do
    from(m in MessageSchema,
      where: m.chat_session_id == ^session_id,
      order_by: [asc: m.inserted_at],
      limit: 1,
      select: m.content
    )
  end

  @doc """
  Gets a message by ID with user ownership verification through session.
  """
  def message_by_id_and_user(message_id, user_id) do
    from(m in MessageSchema,
      join: s in SessionSchema,
      on: m.chat_session_id == s.id,
      where: m.id == ^message_id and s.user_id == ^user_id,
      select: m
    )
  end
end
