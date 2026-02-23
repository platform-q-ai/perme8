defmodule Webhooks.Domain do
  @moduledoc """
  The Domain boundary for the Webhooks context.

  Contains pure business logic: entities (data structures) and policies
  (pure functions for business rules). Has zero external dependencies.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Subscription,
      Entities.Delivery,
      Entities.InboundLog,
      Entities.InboundWebhookConfig,
      Policies.WebhookAuthorizationPolicy,
      Policies.HmacPolicy,
      Policies.RetryPolicy,
      Policies.SecretGeneratorPolicy
    ]
end
