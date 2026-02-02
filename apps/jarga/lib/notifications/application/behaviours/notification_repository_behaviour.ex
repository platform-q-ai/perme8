defmodule Jarga.Notifications.Application.Behaviours.NotificationRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the notification repository contract.
  """

  @type notification :: struct()

  @callback create(map()) :: {:ok, notification} | {:error, Ecto.Changeset.t()}
  @callback get(Ecto.UUID.t()) :: notification | nil
  @callback get_by_user(Ecto.UUID.t(), Ecto.UUID.t()) :: notification | nil
  @callback mark_as_read(notification) :: {:ok, notification} | {:error, Ecto.Changeset.t()}
  @callback mark_action_taken(notification, String.t() | nil) ::
              {:ok, notification} | {:error, Ecto.Changeset.t()}
  @callback transact(function()) :: {:ok, any()} | {:error, any()}
end
