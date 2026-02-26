defmodule Notifications.Infrastructure.Queries.NotificationQueries do
  @moduledoc """
  Composable Ecto query functions for notifications.

  All functions return queryables (not results) and can be
  piped together for flexible query composition.
  """

  import Ecto.Query

  alias Notifications.Infrastructure.Schemas.NotificationSchema

  @doc """
  Returns the base query for notifications.
  """
  @spec base() :: Ecto.Query.t()
  def base do
    from(n in NotificationSchema)
  end

  @doc """
  Filters notifications by user_id.
  """
  @spec by_user(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def by_user(query, user_id) do
    where(query, [n], n.user_id == ^user_id)
  end

  @doc """
  Filters notifications by id.
  """
  @spec by_id(Ecto.Queryable.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def by_id(query, id) do
    where(query, [n], n.id == ^id)
  end

  @doc """
  Filters to only unread notifications.
  """
  @spec unread(Ecto.Queryable.t()) :: Ecto.Query.t()
  def unread(query) do
    where(query, [n], n.read == false)
  end

  @doc """
  Orders notifications by most recent first (inserted_at descending).
  """
  @spec ordered_by_recent(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered_by_recent(query) do
    order_by(query, [n], desc: n.inserted_at)
  end

  @doc """
  Limits the number of results.
  """
  @spec limited(Ecto.Queryable.t(), non_neg_integer()) :: Ecto.Query.t()
  def limited(query, limit) do
    limit(query, ^limit)
  end
end
