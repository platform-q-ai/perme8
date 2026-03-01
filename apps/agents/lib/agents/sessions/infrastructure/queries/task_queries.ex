defmodule Agents.Sessions.Infrastructure.Queries.TaskQueries do
  @moduledoc """
  Composable query functions for session tasks.

  All functions accept a query and return a query, allowing composition.
  """

  import Ecto.Query, warn: false

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @doc """
  Returns the base query for tasks.
  """
  @spec base() :: Ecto.Query.t()
  def base do
    from(t in TaskSchema)
  end

  @doc """
  Filters tasks by user_id.
  """
  @spec for_user(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_user(query \\ base(), user_id) do
    from(t in query, where: t.user_id == ^user_id)
  end

  @doc """
  Filters tasks by status.
  """
  @spec by_status(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_status(query \\ base(), status) do
    from(t in query, where: t.status == ^status)
  end

  @doc """
  Filters tasks by id.
  """
  @spec by_id(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def by_id(query \\ base(), id) do
    from(t in query, where: t.id == ^id)
  end

  @doc """
  Orders tasks by most recent first.
  """
  @spec recent_first(Ecto.Query.t()) :: Ecto.Query.t()
  def recent_first(query \\ base()) do
    from(t in query, order_by: [desc: t.inserted_at, desc: t.id])
  end

  @doc """
  Limits the number of results returned.
  """
  @spec limit(Ecto.Query.t(), non_neg_integer()) :: Ecto.Query.t()
  def limit(query \\ base(), max) do
    from(t in query, limit: ^max)
  end

  @doc """
  Filters tasks by container_id.
  """
  @spec by_container(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_container(query \\ base(), container_id) do
    from(t in query, where: t.container_id == ^container_id)
  end

  @doc """
  Returns sessions grouped by container_id for a user.

  Each session is represented as a map with the container_id,
  the latest task's status, the first task's instruction (as title),
  task count, and timestamps.
  """
  @spec sessions_for_user(Ecto.UUID.t()) :: Ecto.Query.t()
  def sessions_for_user(user_id) do
    from(t in TaskSchema,
      where: t.user_id == ^user_id and not is_nil(t.container_id),
      group_by: t.container_id,
      select: %{
        container_id: t.container_id,
        task_count: count(t.id),
        latest_status: fragment("(array_agg(? ORDER BY ? DESC))[1]", t.status, t.inserted_at),
        title: fragment("(array_agg(? ORDER BY ? ASC))[1]", t.instruction, t.inserted_at),
        image: fragment("(array_agg(? ORDER BY ? ASC))[1]", t.image, t.inserted_at),
        latest_at: max(t.inserted_at),
        created_at: min(t.inserted_at),
        todo_items: fragment("(array_agg(? ORDER BY ? DESC))[1]", t.todo_items, t.inserted_at)
      },
      order_by: [desc: max(t.inserted_at)]
    )
  end
end
