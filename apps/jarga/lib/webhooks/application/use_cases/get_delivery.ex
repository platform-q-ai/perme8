defmodule Jarga.Webhooks.Application.UseCases.GetDelivery do
  @moduledoc """
  Use case for retrieving a webhook delivery by ID.
  Requires admin or owner role.
  """

  alias Jarga.Webhooks.Domain.Policies.WebhookPolicy

  @default_delivery_repository Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepository

  def execute(params, opts \\ []) do
    %{actor: actor, workspace_id: workspace_id, delivery_id: delivery_id} = params

    delivery_repository = Keyword.get(opts, :delivery_repository, @default_delivery_repository)
    membership_checker = Keyword.get(opts, :membership_checker, &default_membership_checker/2)

    with {:ok, member} <- membership_checker.(actor, workspace_id),
         :ok <- authorize(member.role),
         {:ok, delivery} <- fetch(delivery_id, delivery_repository, opts) do
      {:ok, delivery}
    end
  end

  defp authorize(role) do
    if WebhookPolicy.can_manage_webhooks?(role), do: :ok, else: {:error, :forbidden}
  end

  defp fetch(id, repo, opts) do
    case repo.get(id, opts) do
      nil -> {:error, :not_found}
      delivery -> {:ok, delivery}
    end
  end

  defp default_membership_checker(actor, workspace_id) do
    Jarga.Workspaces.get_member(actor, workspace_id)
  end
end
