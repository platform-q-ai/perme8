defmodule Agents.Sessions.Infrastructure.Queries.SessionQueries do
  @moduledoc """
  Composable Ecto query functions for sessions.

  All functions return queryables (not results) for composition.
  """

  import Ecto.Query, warn: false

  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema

  @doc "Base query for sessions."
  def base do
    from(s in SessionSchema, as: :session)
  end

  @doc "Filters sessions by user_id."
  def for_user(query, user_id) do
    from([session: s] in query, where: s.user_id == ^user_id)
  end

  @doc "Filters to a specific session by id."
  def by_id(query, id) do
    from([session: s] in query, where: s.id == ^id)
  end

  @doc "Filters to a specific session by container_id."
  def by_container_id(query, container_id) do
    from([session: s] in query, where: s.container_id == ^container_id)
  end

  @doc "Adds a task_count virtual field via left join and count."
  def with_task_count(query) do
    from([session: s] in query,
      left_join: t in assoc(s, :tasks),
      group_by: s.id,
      select_merge: %{task_count: count(t.id)}
    )
  end

  @doc "Filters to only active sessions."
  def active(query) do
    from([session: s] in query, where: s.status == "active")
  end

  @doc "Orders by most recently updated first."
  def recent_first(query) do
    from([session: s] in query, order_by: [desc: s.updated_at])
  end

  @doc "Limits the number of results."
  def limit(query, limit) do
    from(q in query, limit: ^limit)
  end
end
