defmodule Chat.Infrastructure.Queries.Queries do
  @moduledoc """
  Query objects for the Chat context.
  """

  import Ecto.Query

  alias Chat.Infrastructure.Schemas.{MessageSchema, SessionSchema}

  def session_base do
    from(s in SessionSchema)
  end

  def for_user(query \\ session_base(), user_id) do
    from(s in query, where: s.user_id == ^user_id)
  end

  def by_id_and_user(query \\ session_base(), session_id, user_id) do
    from(s in query, where: s.id == ^session_id and s.user_id == ^user_id)
  end

  def by_id(query \\ session_base(), session_id) do
    from(s in query, where: s.id == ^session_id)
  end

  def with_preloads(query \\ session_base()) do
    from(s in query, preload: [messages: ^messages_ordered()])
  end

  @doc """
  Preloads only the most recent N messages for a session.
  Messages are fetched in descending order by the preload subquery;
  the caller should re-sort ascending for display.

  **Important:** The LIMIT in the preload subquery applies globally, not
  per-session. Only compose with single-session queries (e.g. `by_id/1`).
  """
  def with_paginated_messages(query \\ session_base(), limit) do
    latest_messages =
      from(m in MessageSchema,
        order_by: [desc: m.inserted_at],
        limit: ^limit
      )

    from(s in query, preload: [messages: ^latest_messages])
  end

  def ordered_by_recent(query \\ session_base()) do
    from(s in query, order_by: [desc: s.updated_at, desc: s.inserted_at])
  end

  def limit_results(query, limit) do
    from(q in query, limit: ^limit)
  end

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

  @doc """
  Returns sessions with message count and first message preview in a single query.
  Eliminates the N+1 pattern of fetching previews per session.
  """
  def with_message_count_and_preview(query \\ session_base()) do
    first_message_subquery =
      from(m in MessageSchema,
        distinct: m.chat_session_id,
        order_by: [asc: m.inserted_at],
        select: %{chat_session_id: m.chat_session_id, content: m.content}
      )

    from(s in query,
      left_join: m in assoc(s, :messages),
      left_join: fm in subquery(first_message_subquery),
      on: fm.chat_session_id == s.id,
      group_by: [s.id, fm.content],
      select: %{
        id: s.id,
        title: s.title,
        inserted_at: s.inserted_at,
        updated_at: s.updated_at,
        message_count: count(m.id),
        preview: fm.content
      }
    )
  end

  def message_base do
    from(m in MessageSchema)
  end

  def for_session(query \\ message_base(), session_id) do
    from(m in query, where: m.chat_session_id == ^session_id)
  end

  def messages_ordered do
    from(m in MessageSchema, order_by: [asc: m.inserted_at])
  end

  def first_message_content(session_id) do
    from(m in MessageSchema,
      where: m.chat_session_id == ^session_id,
      order_by: [asc: m.inserted_at],
      limit: 1,
      select: m.content
    )
  end

  @doc """
  Returns messages for a session before a given cursor, ordered by most recent first.
  Fetches `limit` messages older than `before_id`.

  Uses a cross join to the cursor message to compare timestamps. Messages with
  the same timestamp as the cursor (but different ID) are included to handle
  second-precision timestamp collisions.
  """
  def messages_before(session_id, before_id, limit) do
    cursor_query =
      from(c in MessageSchema,
        where: c.id == ^before_id,
        select: %{inserted_at: c.inserted_at}
      )

    from(m in MessageSchema,
      join: cursor in subquery(cursor_query),
      on: true,
      where: m.chat_session_id == ^session_id,
      where: m.id != ^before_id,
      where: m.inserted_at <= cursor.inserted_at,
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
  end

  def message_by_id_and_user(message_id, user_id) do
    from(m in MessageSchema,
      join: s in SessionSchema,
      on: m.chat_session_id == s.id,
      where: m.id == ^message_id and s.user_id == ^user_id,
      select: m
    )
  end

  # --- Orphan detection and cleanup queries ---

  @doc """
  Returns up to `limit` distinct user_id values from chat_sessions,
  sampled randomly. Used by OrphanDetectionWorker for sample-based
  orphan detection (not a full table scan).

  Uses a subquery to first get distinct user_ids, then samples randomly,
  because PostgreSQL requires ORDER BY expressions to appear in the SELECT
  list when using DISTINCT.
  """
  def sample_distinct_user_ids(limit) do
    distinct_users =
      from(s in SessionSchema,
        distinct: true,
        select: %{user_id: s.user_id}
      )

    from(u in subquery(distinct_users),
      select: u.user_id,
      order_by: fragment("RANDOM()"),
      limit: ^limit
    )
  end

  @doc """
  Returns a queryable for all sessions belonging to a specific user.
  Used by OrphanDetectionWorker to delete sessions for orphaned users.
  """
  def sessions_for_user(user_id) do
    from(s in SessionSchema, where: s.user_id == ^user_id)
  end

  @doc """
  Returns a queryable for sessions belonging to a specific user AND workspace.
  Used by IdentityEventSubscriber to clean up sessions when a user is removed
  from a workspace.
  """
  def sessions_for_user_and_workspace(user_id, workspace_id) do
    from(s in SessionSchema,
      where: s.user_id == ^user_id and s.workspace_id == ^workspace_id
    )
  end
end
