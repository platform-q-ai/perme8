defmodule Identity.Application.Behaviours.PubSubNotifierBehaviour do
  @moduledoc """
  Behaviour defining the PubSub notification contract for workspaces.
  """

  @callback broadcast_invitation_created(
              Ecto.UUID.t(),
              Ecto.UUID.t(),
              String.t(),
              String.t(),
              String.t()
            ) :: :ok
end
