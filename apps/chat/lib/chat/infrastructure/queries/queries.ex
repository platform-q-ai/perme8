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

  def message_by_id_and_user(message_id, user_id) do
    from(m in MessageSchema,
      join: s in SessionSchema,
      on: m.chat_session_id == s.id,
      where: m.id == ^message_id and s.user_id == ^user_id,
      select: m
    )
  end
end
