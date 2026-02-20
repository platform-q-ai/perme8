defmodule Agents.Sessions.Infrastructure.Queries.TaskQueries do
  @moduledoc """
  Composable query functions for session tasks.

  All functions accept a query and return a query, allowing composition.
  """

  import Ecto.Query, warn: false

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @active_statuses ["pending", "starting", "running"]

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
    from(t in query, order_by: [desc: t.inserted_at])
  end

  @doc """
  Returns a query that counts active tasks (pending, starting, running) for a user.
  """
  @spec running_count_for_user(Ecto.UUID.t()) :: Ecto.Query.t()
  def running_count_for_user(user_id) do
    from(t in TaskSchema,
      where: t.user_id == ^user_id and t.status in ^@active_statuses,
      select: count(t.id)
    )
  end
end
