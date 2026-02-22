defmodule Jarga.Webhooks.Domain do
  @moduledoc """
  Domain layer boundary for the Webhooks context.

  Contains pure business logic with no external dependencies:

  ## Entities
  - `Entities.WebhookSubscription` - Outbound webhook subscription
  - `Entities.WebhookDelivery` - Delivery attempt tracking
  - `Entities.InboundWebhook` - Inbound webhook audit record

  ## Policies (Pure Functions)
  - `Policies.WebhookPolicy` - Authorization rules
  - `Policies.DeliveryPolicy` - Retry logic and backoff
  - `Policies.SignaturePolicy` - HMAC signing and verification
  - `Policies.EventFilterPolicy` - Event type matching

  ## Events
  - Domain events emitted by use cases

  ## Dependency Rule

  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases)
  - Infrastructure layer (repos, schemas)
  - External libraries (Ecto, Phoenix, etc.)
  - Other contexts
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.WebhookSubscription,
      Entities.WebhookDelivery,
      Entities.InboundWebhook,
      Policies.WebhookPolicy,
      Policies.DeliveryPolicy,
      Policies.SignaturePolicy,
      Policies.EventFilterPolicy,
      Events.WebhookSubscriptionCreated,
      Events.WebhookSubscriptionUpdated,
      Events.WebhookSubscriptionDeleted,
      Events.WebhookDeliveryCompleted,
      Events.InboundWebhookReceived
    ]
end
