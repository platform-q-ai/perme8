defmodule Webhooks.Application.UseCases.CreateSubscription do
  @moduledoc """
  Use case for creating an outbound webhook subscription.

  ## Business Rules

  - Actor must have admin or owner role in the workspace
  - A cryptographically secure secret is auto-generated
  - The returned subscription includes the secret (only time it's visible)

  ## Dependencies (injectable via opts)

  - `:subscription_repository` - Repository for subscription persistence
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy
  alias Webhooks.Domain.Policies.SecretGeneratorPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      member_role: member_role,
      url: url,
      event_types: event_types
    } = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role) do
      secret = SecretGeneratorPolicy.generate()

      attrs = %{
        url: url,
        secret: secret,
        event_types: event_types,
        workspace_id: workspace_id,
        created_by_id: Map.get(params, :created_by_id),
        is_active: true
      }

      subscription_repository.insert(attrs, repo)
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end
end
