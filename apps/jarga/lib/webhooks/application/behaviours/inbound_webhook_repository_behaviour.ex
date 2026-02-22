defmodule Jarga.Webhooks.Application.Behaviours.InboundWebhookRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the interface for inbound webhook audit log persistence.

  Infrastructure layer implementations must implement all callbacks.
  """

  @callback insert(map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback list_for_workspace(String.t(), keyword()) :: [struct()]
  @callback get_inbound_secret(String.t(), keyword()) ::
              {:ok, String.t()} | {:error, :not_configured}
end
