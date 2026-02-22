defmodule Jarga.Webhooks.Application.UseCases.ListWebhookSubscriptions do
  @moduledoc """
  Use case for listing webhook subscriptions for a workspace.
  Requires admin or owner role.
  """

  alias Jarga.Webhooks.Domain.Policies.WebhookPolicy

  @default_webhook_repository Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository

  def execute(params, opts \\ []) do
    %{actor: actor, workspace_id: workspace_id} = params

    webhook_repository = Keyword.get(opts, :webhook_repository, @default_webhook_repository)
    membership_checker = Keyword.get(opts, :membership_checker, &default_membership_checker/2)

    with {:ok, member} <- membership_checker.(actor, workspace_id),
         :ok <- authorize(member.role) do
      {:ok, webhook_repository.list_for_workspace(workspace_id, opts)}
    end
  end

  defp authorize(role) do
    if WebhookPolicy.can_manage_webhooks?(role), do: :ok, else: {:error, :forbidden}
  end

  defp default_membership_checker(actor, workspace_id) do
    Jarga.Workspaces.get_member(actor, workspace_id)
  end
end
