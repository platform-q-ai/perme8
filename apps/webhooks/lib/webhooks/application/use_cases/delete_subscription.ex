defmodule Webhooks.Application.UseCases.DeleteSubscription do
  @moduledoc """
  Use case for deleting an outbound webhook subscription.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: _workspace_id,
      member_role: member_role,
      subscription_id: subscription_id
    } = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role) do
      subscription_repository.delete(subscription_id, repo)
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end
end
