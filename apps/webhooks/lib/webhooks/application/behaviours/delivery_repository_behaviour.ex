defmodule Webhooks.Application.Behaviours.DeliveryRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the delivery repository contract.

  Implementations handle persistence of webhook delivery records.
  """

  alias Webhooks.Domain.Entities.Delivery

  @type repo :: module()

  @callback insert(attrs :: map(), repo) ::
              {:ok, Delivery.t()} | {:error, Ecto.Changeset.t()}

  @callback get_by_id(delivery_id :: String.t(), workspace_id :: String.t(), repo) ::
              {:ok, Delivery.t()} | {:error, :not_found}

  @callback list_for_subscription(subscription_id :: String.t(), repo) ::
              {:ok, [Delivery.t()]}

  @callback update_status(delivery_id :: String.t(), attrs :: map(), repo) ::
              {:ok, Delivery.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}

  @callback list_pending_retries(repo) :: {:ok, [Delivery.t()]}
end
