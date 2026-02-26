defmodule Notifications.Infrastructure.Repositories.NotificationRepository do
  @moduledoc """
  Repository for notification data access.

  Uses `Notifications.Repo` for all database operations (NOT Identity.Repo).
  Uses `NotificationQueries` for composable query construction.
  """

  @behaviour Notifications.Application.Behaviours.NotificationRepositoryBehaviour

  alias Notifications.Infrastructure.Queries.NotificationQueries
  alias Notifications.Infrastructure.Schemas.NotificationSchema
  alias Notifications.Repo

  @doc """
  Creates a notification.
  """
  @impl true
  def create(attrs) do
    attrs
    |> NotificationSchema.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Gets a notification by ID.
  """
  @impl true
  def get(id), do: Repo.get(NotificationSchema, id)

  @doc """
  Gets a notification by ID for a specific user.
  """
  @impl true
  def get_by_user(id, user_id) do
    NotificationQueries.base()
    |> NotificationQueries.by_id(id)
    |> NotificationQueries.by_user(user_id)
    |> Repo.one()
  end

  @doc """
  Lists all notifications for a user, ordered by most recent.
  """
  @impl true
  def list_by_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      NotificationQueries.base()
      |> NotificationQueries.by_user(user_id)
      |> NotificationQueries.ordered_by_recent()

    query =
      if limit do
        NotificationQueries.limited(query, limit)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists unread notifications for a user.

  ## Options
    * `:limit` - Maximum number of notifications to return
  """
  @impl true
  def list_unread_by_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      NotificationQueries.base()
      |> NotificationQueries.by_user(user_id)
      |> NotificationQueries.unread()
      |> NotificationQueries.ordered_by_recent()

    query =
      if limit do
        NotificationQueries.limited(query, limit)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  @impl true
  def count_unread_by_user(user_id) do
    NotificationQueries.base()
    |> NotificationQueries.by_user(user_id)
    |> NotificationQueries.unread()
    |> Repo.aggregate(:count)
  end

  @doc """
  Marks a notification as read.
  """
  @impl true
  def mark_as_read(notification) do
    notification
    |> NotificationSchema.mark_read_changeset()
    |> Repo.update()
  end

  @doc """
  Marks all notifications as read for a user.
  Returns the number of updated notifications.
  """
  @impl true
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      NotificationQueries.base()
      |> NotificationQueries.by_user(user_id)
      |> NotificationQueries.unread()
      |> Repo.update_all(set: [read: true, read_at: now, updated_at: now])

    {:ok, count}
  end

  @doc """
  Executes a transaction with unwrapping support.
  This allows use cases to run database operations in a transaction
  without directly depending on Repo.
  """
  @impl true
  def transact(fun) when is_function(fun, 0) do
    Repo.transact(fun)
  end
end
