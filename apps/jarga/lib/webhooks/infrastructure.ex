defmodule Jarga.Webhooks.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Webhooks context.

  Contains database schemas, query objects, repositories, HTTP client,
  and event handler subscribers.

  ## Schemas
  - `Schemas.WebhookSubscriptionSchema` - Ecto schema for subscriptions
  - `Schemas.WebhookDeliverySchema` - Ecto schema for deliveries
  - `Schemas.InboundWebhookSchema` - Ecto schema for inbound webhooks

  ## Queries
  - `Queries.WebhookQueries` - Subscription query objects
  - `Queries.DeliveryQueries` - Delivery query objects
  - `Queries.InboundWebhookQueries` - Inbound webhook query objects

  ## Repositories
  - `Repositories.WebhookRepository` - Subscription data access
  - `Repositories.DeliveryRepository` - Delivery data access
  - `Repositories.InboundWebhookRepository` - Inbound webhook data access

  ## Services
  - `Services.HttpClient` - Outbound HTTP POST client

  ## Subscribers
  - `Subscribers.WebhookDispatchSubscriber` - PubSub event listener for dispatch
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Webhooks.Domain,
      Jarga.Webhooks.Application,
      Identity.Repo,
      Identity,
      Perme8.Events
    ],
    exports: [
      Schemas.WebhookSubscriptionSchema,
      Schemas.WebhookDeliverySchema,
      Schemas.InboundWebhookSchema,
      Repositories.WebhookRepository,
      Repositories.DeliveryRepository,
      Repositories.InboundWebhookRepository,
      Services.HttpClient,
      Queries.WebhookQueries,
      Queries.DeliveryQueries,
      Queries.InboundWebhookQueries,
      Subscribers.WebhookDispatchSubscriber
    ]
end
