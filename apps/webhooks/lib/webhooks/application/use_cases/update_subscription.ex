defmodule Webhooks.Application.UseCases.UpdateSubscription do
  @moduledoc """
  Use case for updating an outbound webhook subscription.

  Returns the updated subscription with secret stripped for security.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: _workspace_id,
      member_role: member_role,
      subscription_id: subscription_id,
      attrs: attrs
    } = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role),
         {:ok, subscription} <- subscription_repository.update(subscription_id, attrs, repo) do
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
