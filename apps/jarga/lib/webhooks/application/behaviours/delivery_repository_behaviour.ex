defmodule Jarga.Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the interface for webhook delivery persistence.

  Infrastructure layer implementations must implement all callbacks.
  """

  @callback insert(map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback update(struct(), map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback get(String.t(), keyword()) :: struct() | nil
  @callback list_for_subscription(String.t(), keyword()) :: [struct()]
  @callback list_pending_retries(keyword()) :: [struct()]
end
