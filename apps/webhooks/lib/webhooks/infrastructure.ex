defmodule Webhooks.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Webhooks context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.SubscriptionSchema` - Outbound webhook subscriptions
  - `Schemas.DeliverySchema` - Webhook delivery records
  - `Schemas.InboundWebhookConfigSchema` - Inbound webhook configurations
  - `Schemas.InboundLogSchema` - Inbound webhook audit logs

  ## Repositories (Data Access)
  - `Repositories.SubscriptionRepository` - Subscription CRUD
  - `Repositories.DeliveryRepository` - Delivery persistence
  - `Repositories.InboundLogRepository` - Inbound log persistence
  - `Repositories.InboundWebhookConfigRepository` - Inbound config lookup

  ## Queries (Ecto Query Builders)
  - `Queries.SubscriptionQueries` - Subscription query operations
  - `Queries.DeliveryQueries` - Delivery query operations
  - `Queries.InboundLogQueries` - Inbound log query operations

  ## Services
  - `Services.HttpDispatcher` - HTTP POST dispatch for outbound webhooks

  ## Subscribers (Event Handlers)
  - `Subscribers.OutboundWebhookHandler` - Listens for project/document events

  ## Workers
  - `Workers.RetryWorker` - Periodic retry of failed deliveries

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities and policies)
  - Application layer (to implement service behaviours)
  - WebhooksApi.Repo (database access)
  - Perme8.Events (EventHandler behaviour)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Webhooks.Domain,
      Webhooks.Application,
      WebhooksApi.Repo,
      Perme8.Events,
      Jarga.Projects.Domain,
      Jarga.Documents.Domain
    ],
    exports: [
      Schemas.SubscriptionSchema,
      Schemas.DeliverySchema,
      Schemas.InboundLogSchema,
      Schemas.InboundWebhookConfigSchema,
      Repositories.SubscriptionRepository,
      Repositories.DeliveryRepository,
      Repositories.InboundLogRepository,
      Repositories.InboundWebhookConfigRepository,
      Queries.SubscriptionQueries,
      Queries.DeliveryQueries,
      Queries.InboundLogQueries,
      Services.HttpDispatcher,
      Subscribers.OutboundWebhookHandler,
      Workers.RetryWorker
    ]
end
