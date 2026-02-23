defmodule Webhooks.Application.Behaviours.SubscriptionRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the subscription repository contract.

  Implementations handle persistence of outbound webhook subscriptions.
  """

  alias Webhooks.Domain.Entities.Subscription

  @type repo :: module()

  @callback insert(attrs :: map(), repo) ::
              {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}

  @callback update(
              subscription_id :: String.t(),
              workspace_id :: String.t(),
              attrs :: map(),
              repo
            ) ::
              {:ok, Subscription.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}

  @callback delete(subscription_id :: String.t(), workspace_id :: String.t(), repo) ::
              {:ok, Subscription.t()} | {:error, :not_found}

  @callback get_by_id(subscription_id :: String.t(), workspace_id :: String.t(), repo) ::
              {:ok, Subscription.t()} | {:error, :not_found}

  @callback list_for_workspace(workspace_id :: String.t(), repo) ::
              {:ok, [Subscription.t()]}

  @callback list_active_for_event_type(
              workspace_id :: String.t(),
              event_type :: String.t(),
              repo
            ) :: {:ok, [Subscription.t()]}
end
