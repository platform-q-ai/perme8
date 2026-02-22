defmodule Jarga.Webhooks.Application do
  @moduledoc """
  Application layer boundary for the Webhooks context.

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Use Cases
  - CRUD operations for webhook subscriptions
  - Webhook delivery dispatch and retry
  - Inbound webhook processing
  - Delivery and audit log queries

  ## Behaviours (Interfaces for Infrastructure)
  - `WebhookRepositoryBehaviour`
  - `DeliveryRepositoryBehaviour`
  - `InboundWebhookRepositoryBehaviour`
  - `HttpClientBehaviour`

  ## Dependency Rule

  The Application layer may only depend on:
  - Domain layer (same context)
  - Cross-context facades (Identity, Workspaces)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Webhooks.Domain,
      Perme8.Events,
      Identity,
      Jarga.Workspaces
    ],
    exports: [
      UseCases.CreateWebhookSubscription,
      UseCases.ListWebhookSubscriptions,
      UseCases.GetWebhookSubscription,
      UseCases.UpdateWebhookSubscription,
      UseCases.DeleteWebhookSubscription,
      UseCases.DispatchWebhookDelivery,
      UseCases.RetryWebhookDelivery,
      UseCases.ListDeliveries,
      UseCases.GetDelivery,
      UseCases.ProcessInboundWebhook,
      UseCases.ListInboundWebhookLogs,
      Behaviours.WebhookRepositoryBehaviour,
      Behaviours.DeliveryRepositoryBehaviour,
      Behaviours.InboundWebhookRepositoryBehaviour,
      Behaviours.HttpClientBehaviour
    ]
end
