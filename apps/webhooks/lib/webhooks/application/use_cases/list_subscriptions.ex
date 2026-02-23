defmodule Webhooks.Application.UseCases.ListSubscriptions do
  @moduledoc """
  Use case for listing outbound webhook subscriptions for a workspace.

  Returns subscriptions with secrets stripped for security.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository

  @impl true
  def execute(params, opts \\ []) do
    %{workspace_id: workspace_id, member_role: member_role} = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role),
         {:ok, subscriptions} <- subscription_repository.list_for_workspace(workspace_id, repo) do
      {:ok, Enum.map(subscriptions, &strip_secret/1)}
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end

  defp strip_secret(subscription), do: %{subscription | secret: nil}
end
