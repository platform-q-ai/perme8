defmodule Jarga.Webhooks.Application.Behaviours.WebhookRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the interface for webhook subscription persistence.

  Infrastructure layer implementations must implement all callbacks.
  """

  @callback insert(map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback update(struct(), map(), keyword()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback delete(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  @callback get(String.t(), keyword()) :: struct() | nil
  @callback list_for_workspace(String.t(), keyword()) :: [struct()]
  @callback list_active_for_event(String.t(), String.t(), keyword()) :: [struct()]
end
