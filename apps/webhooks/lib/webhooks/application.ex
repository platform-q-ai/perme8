defmodule Webhooks.Application do
  @moduledoc """
  Application layer boundary for the Webhooks context.

  Contains use cases that orchestrate domain logic and infrastructure
  services for webhook management, and behaviour definitions for
  infrastructure dependencies (repository contracts, HTTP dispatcher).

  ## Use Cases

  - `CreateSubscription` - Create outbound webhook subscription
  - `ListSubscriptions` - List subscriptions for a workspace
  - `GetSubscription` - Get a single subscription
  - `UpdateSubscription` - Update subscription attributes
  - `DeleteSubscription` - Delete a subscription
  - `ListDeliveries` - List delivery records for a subscription
  - `GetDelivery` - Get a single delivery record
  - `DispatchWebhook` - Dispatch outbound webhook to matching subscriptions
  - `ReceiveInboundWebhook` - Receive and verify inbound webhook
  - `ListInboundLogs` - List inbound webhook audit logs
  - `RetryDelivery` - Retry a failed delivery

  ## Dependency Rule

  The Application layer depends on:
  - Domain layer (same context) for entities and policies
  - Cross-context public APIs via dependency injection
  """

  use Boundary,
    top_level?: true,
    deps: [
      Webhooks.Domain
    ],
    exports: [
      UseCases.UseCase,
      UseCases.CreateSubscription,
      UseCases.ListSubscriptions,
      UseCases.GetSubscription,
      UseCases.UpdateSubscription,
      UseCases.DeleteSubscription,
      UseCases.ListDeliveries,
      UseCases.GetDelivery,
      UseCases.DispatchWebhook,
      UseCases.ReceiveInboundWebhook,
      UseCases.ListInboundLogs,
      UseCases.RetryDelivery,
      Behaviours.SubscriptionRepositoryBehaviour,
      Behaviours.DeliveryRepositoryBehaviour,
      Behaviours.InboundLogRepositoryBehaviour,
      Behaviours.InboundWebhookConfigRepositoryBehaviour,
      Behaviours.HttpDispatcherBehaviour
    ]
end
