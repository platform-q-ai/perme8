defmodule Webhooks.Application.UseCases.GetSubscription do
  @moduledoc """
  Use case for retrieving a single outbound webhook subscription.

  Returns the subscription with secret stripped for security.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      member_role: member_role,
      subscription_id: subscription_id
    } = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role),
         {:ok, subscription} <-
           subscription_repository.get_by_id(subscription_id, workspace_id, repo) do
      {:ok, strip_secret(subscription)}
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end

  defp strip_secret(subscription), do: %{subscription | secret: nil}
end
