defmodule Webhooks.Application.UseCases.GetDelivery do
  @moduledoc """
  Use case for retrieving a single delivery record with full details.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_delivery_repository Webhooks.Infrastructure.Repositories.DeliveryRepository

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      member_role: member_role,
      delivery_id: delivery_id
    } = params

    delivery_repository =
      Keyword.get(opts, :delivery_repository, @default_delivery_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role) do
      delivery_repository.get_by_id(delivery_id, workspace_id, repo)
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end
end
