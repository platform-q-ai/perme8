defmodule Notifications.Application.Behaviours.NotificationRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the notification repository contract.

  Intentionally excludes `mark_action_taken` — action handling
  has been removed from the Notifications bounded context.
  """

  @type notification :: struct()

  @callback create(map()) :: {:ok, notification} | {:error, Ecto.Changeset.t()}
  @callback get(Ecto.UUID.t()) :: notification | nil
  @callback get_by_user(Ecto.UUID.t(), Ecto.UUID.t()) :: notification | nil
  @callback mark_as_read(notification) :: {:ok, notification} | {:error, Ecto.Changeset.t()}
  @callback mark_all_as_read(Ecto.UUID.t()) :: {:ok, non_neg_integer()}
  @callback list_by_user(Ecto.UUID.t(), keyword()) :: [notification]
  @callback list_unread_by_user(Ecto.UUID.t(), keyword()) :: [notification]
  @callback count_unread_by_user(Ecto.UUID.t()) :: non_neg_integer()
  @callback transact(function()) :: {:ok, any()} | {:error, any()}
end
