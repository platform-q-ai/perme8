defmodule Webhooks.Application.UseCases.ListDeliveries do
  @moduledoc """
  Use case for listing delivery records for a subscription.

  Verifies the subscription exists before listing deliveries.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository
  @default_delivery_repository Webhooks.Infrastructure.Repositories.DeliveryRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      member_role: member_role,
      subscription_id: subscription_id
    } = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    delivery_repository =
      Keyword.get(opts, :delivery_repository, @default_delivery_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role),
         {:ok, _subscription} <-
           subscription_repository.get_by_id(subscription_id, workspace_id, repo) do
      delivery_repository.list_for_subscription(subscription_id, repo)
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end
end
