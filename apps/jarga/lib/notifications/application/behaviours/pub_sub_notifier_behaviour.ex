defmodule Jarga.Notifications.Application.Behaviours.PubSubNotifierBehaviour do
  @moduledoc """
  Behaviour defining the PubSub notification contract for notifications.
  """

  @callback broadcast_invitation_created(
              Ecto.UUID.t(),
              Ecto.UUID.t(),
              String.t(),
              String.t(),
              String.t()
            ) :: :ok
  @callback broadcast_workspace_joined(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
  @callback broadcast_invitation_declined(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
  @callback broadcast_new_notification(Ecto.UUID.t(), struct()) :: :ok
end
