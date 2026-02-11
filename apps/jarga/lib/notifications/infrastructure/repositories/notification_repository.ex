defmodule Jarga.Notifications.Infrastructure.Repositories.NotificationRepository do
  @moduledoc """
  Repository for notification data access.
  """

  @behaviour Jarga.Notifications.Application.Behaviours.NotificationRepositoryBehaviour

  import Ecto.Query
  alias Jarga.Notifications.Infrastructure.Schemas.NotificationSchema
  # All database operations use Identity.Repo to ensure consistent visibility
  # of user data (users table is managed by Identity.Repo)
  alias Identity.Repo, as: Repo

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
    NotificationSchema
    |> where([n], n.id == ^id and n.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Lists all notifications for a user, ordered by most recent.
  """
  def list_by_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    NotificationSchema
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  @doc """
  Lists unread notifications for a user.
  """
  def list_unread_by_user(user_id) do
    NotificationSchema
    |> where([n], n.user_id == ^user_id and n.read == false)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  def count_unread_by_user(user_id) do
    NotificationSchema
    |> where([n], n.user_id == ^user_id and n.read == false)
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
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      NotificationSchema
      |> where([n], n.user_id == ^user_id and n.read == false)
      |> Repo.update_all(set: [read: true, read_at: now, updated_at: now])

    {:ok, count}
  end

  @doc """
  Marks when action was taken on a notification.
  Optionally stores the action type in the data field.
  """
  @impl true
  def mark_action_taken(notification, action \\ nil) do
    changeset = NotificationSchema.mark_action_taken_changeset(notification)

    changeset =
      if action do
        # Store the action in the data field
        new_data = Map.put(notification.data, "action", action)
        Ecto.Changeset.put_change(changeset, :data, new_data)
      else
        changeset
      end

    Repo.update(changeset)
  end

  @doc """
  Updates a notification with the given changeset.
  Raises on error.
  For test fixtures only.
  """
  def update!(changeset) do
    Repo.update!(changeset)
  end

  @doc """
  Deletes a notification.
  """
  def delete(notification) do
    Repo.delete(notification)
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

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)
end
