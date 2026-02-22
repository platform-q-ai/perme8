defmodule Jarga.Webhooks do
  @moduledoc """
  The Webhooks context.

  Provides outbound webhook subscriptions (workspace admins register HTTP endpoints
  for domain event delivery) and inbound webhook processing (authenticated receiver
  endpoints verify HMAC signatures and audit-log requests).

  ## Public API

  All functions delegate to use cases with real infrastructure injected.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Identity,
      Jarga.Workspaces,
      Jarga.Webhooks.Domain,
      Jarga.Webhooks.Application,
      Jarga.Webhooks.Infrastructure,
      Identity.Repo
    ],
    exports: [
      {Domain.Entities.WebhookSubscription, []},
      {Domain.Entities.WebhookDelivery, []},
      {Domain.Entities.InboundWebhook, []}
    ]

  alias Jarga.Webhooks.Application.UseCases.{
    CreateWebhookSubscription,
    ListWebhookSubscriptions,
    GetWebhookSubscription,
    UpdateWebhookSubscription,
    DeleteWebhookSubscription,
    DispatchWebhookDelivery,
    RetryWebhookDelivery,
    ListDeliveries,
    GetDelivery,
    ProcessInboundWebhook,
    ListInboundWebhookLogs
  }

  # Outbound Webhook Subscriptions

  @doc "Creates a webhook subscription for a workspace."
  def create_subscription(actor, workspace_id, attrs, opts \\ []) do
    CreateWebhookSubscription.execute(
      %{actor: actor, workspace_id: workspace_id, attrs: attrs},
      default_opts(opts)
    )
  end

  @doc "Lists webhook subscriptions for a workspace."
  def list_subscriptions(actor, workspace_id, opts \\ []) do
    ListWebhookSubscriptions.execute(
      %{actor: actor, workspace_id: workspace_id},
      default_opts(opts)
    )
  end

  @doc "Gets a webhook subscription by ID."
  def get_subscription(actor, workspace_id, subscription_id, opts \\ []) do
    GetWebhookSubscription.execute(
      %{actor: actor, workspace_id: workspace_id, subscription_id: subscription_id},
      default_opts(opts)
    )
  end

  @doc "Updates a webhook subscription."
  def update_subscription(actor, workspace_id, subscription_id, attrs, opts \\ []) do
    UpdateWebhookSubscription.execute(
      %{
        actor: actor,
        workspace_id: workspace_id,
        subscription_id: subscription_id,
        attrs: attrs
      },
      default_opts(opts)
    )
  end

  @doc "Deletes a webhook subscription."
  def delete_subscription(actor, workspace_id, subscription_id, opts \\ []) do
    DeleteWebhookSubscription.execute(
      %{actor: actor, workspace_id: workspace_id, subscription_id: subscription_id},
      default_opts(opts)
    )
  end

  # Deliveries

  @doc "Lists deliveries for a webhook subscription."
  def list_deliveries(actor, workspace_id, subscription_id, opts \\ []) do
    ListDeliveries.execute(
      %{actor: actor, workspace_id: workspace_id, subscription_id: subscription_id},
      default_opts(opts)
    )
  end

  @doc "Gets a delivery by ID."
  def get_delivery(actor, workspace_id, delivery_id, opts \\ []) do
    GetDelivery.execute(
      %{actor: actor, workspace_id: workspace_id, delivery_id: delivery_id},
      default_opts(opts)
    )
  end

  @doc "Dispatches a webhook delivery to a subscription's URL."
  def dispatch_delivery(subscription, event_type, payload, opts \\ []) do
    params = %{subscription: subscription, event_type: event_type, payload: payload}

    # Forward max_attempts to params if provided in opts
    params =
      case Keyword.get(opts, :max_attempts) do
        nil -> params
        max -> Map.put(params, :max_attempts, max)
      end

    DispatchWebhookDelivery.execute(params, default_opts(opts))
  end

  @doc "Retries a failed webhook delivery."
  def retry_delivery(delivery, _subscription, opts \\ []) do
    RetryWebhookDelivery.execute(
      %{delivery_id: delivery.id},
      default_opts(opts)
    )
  end

  # Inbound Webhooks

  @doc "Processes an inbound webhook request."
  def process_inbound_webhook(params, opts \\ []) do
    ProcessInboundWebhook.execute(params, default_opts(opts))
  end

  @doc "Lists inbound webhook audit logs for a workspace."
  def list_inbound_logs(actor, workspace_id, opts \\ []) do
    ListInboundWebhookLogs.execute(
      %{actor: actor, workspace_id: workspace_id},
      default_opts(opts)
    )
  end

  # Injects the real infrastructure implementations as default opts
  defp default_opts(opts) do
    Keyword.merge(
      [
        webhook_repository: Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository,
        delivery_repository: Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepository,
        inbound_webhook_repository:
          Jarga.Webhooks.Infrastructure.Repositories.InboundWebhookRepository,
        http_client: Jarga.Webhooks.Infrastructure.Services.HttpClient,
        event_bus: Perme8.Events.EventBus
      ],
      opts
    )
  end
end
