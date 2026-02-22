defmodule Jarga.Webhooks.Application.UseCases.UpdateWebhookSubscription do
  @moduledoc """
  Use case for updating a webhook subscription.
  Requires admin or owner role. Emits WebhookSubscriptionUpdated event.
  """

  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionUpdated
  alias Jarga.Webhooks.Domain.Policies.WebhookPolicy

  @default_webhook_repository Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository
  @default_event_bus Perme8.Events.EventBus

  def execute(params, opts \\ []) do
    %{
      actor: actor,
      workspace_id: workspace_id,
      subscription_id: subscription_id,
      attrs: attrs
    } = params

    webhook_repository = Keyword.get(opts, :webhook_repository, @default_webhook_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])
    membership_checker = Keyword.get(opts, :membership_checker, &default_membership_checker/2)

    with {:ok, member} <- membership_checker.(actor, workspace_id),
         :ok <- authorize(member.role),
         {:ok, existing} <- fetch(subscription_id, webhook_repository, opts),
         {:ok, updated} <- webhook_repository.update(existing, attrs, opts) do
      emit_event(updated, actor, workspace_id, attrs, event_bus, event_bus_opts)
      {:ok, updated}
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

  defp emit_event(subscription, actor, workspace_id, changes, event_bus, event_bus_opts) do
    event =
      WebhookSubscriptionUpdated.new(%{
        aggregate_id: subscription.id,
        actor_id: actor.id,
        workspace_id: workspace_id,
        changes: changes
      })

    event_bus.emit(event, event_bus_opts)
  end

  defp default_membership_checker(actor, workspace_id) do
    Jarga.Workspaces.get_member(actor, workspace_id)
  end
end
