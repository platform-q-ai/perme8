defmodule Jarga.Webhooks.Application.UseCases.GetWebhookSubscription do
  @moduledoc """
  Use case for retrieving a webhook subscription by ID.
  Requires admin or owner role.
  """

  alias Jarga.Webhooks.Domain.Policies.WebhookPolicy

  @default_webhook_repository Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository

  def execute(params, opts \\ []) do
    %{actor: actor, workspace_id: workspace_id, subscription_id: subscription_id} = params

    webhook_repository = Keyword.get(opts, :webhook_repository, @default_webhook_repository)
    membership_checker = Keyword.get(opts, :membership_checker, &default_membership_checker/2)

    with {:ok, member} <- membership_checker.(actor, workspace_id),
         :ok <- authorize(member.role) do
      fetch(subscription_id, webhook_repository, opts)
    end
  end

  defp authorize(role) do
    if WebhookPolicy.can_manage_webhooks?(role), do: :ok, else: {:error, :forbidden}
  end

  defp fetch(id, repo, opts) do
    case repo.get(id, opts) do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription}
    end
  end

  defp default_membership_checker(actor, workspace_id) do
    Jarga.Workspaces.get_member(actor, workspace_id)
  end
end
