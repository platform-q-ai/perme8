defmodule WebhooksApi.Router do
  use WebhooksApi, :router

  pipeline :api_base do
    plug(:accepts, ["json"])
    plug(WebhooksApi.Plugs.SecurityHeadersPlug)
  end

  pipeline :api_authenticated do
    plug(WebhooksApi.Plugs.ApiAuthPlug)
  end

  # Authenticated outbound webhook management routes
  scope "/api", WebhooksApi do
    pipe_through([:api_base, :api_authenticated])

    # Inbound webhook audit logs (must be ABOVE wildcard :id routes)
    get("/workspaces/:workspace_slug/webhooks/inbound/logs", InboundLogApiController, :index)

    # Subscription CRUD
    get("/workspaces/:workspace_slug/webhooks", SubscriptionApiController, :index)
    post("/workspaces/:workspace_slug/webhooks", SubscriptionApiController, :create)
    get("/workspaces/:workspace_slug/webhooks/:id", SubscriptionApiController, :show)
    patch("/workspaces/:workspace_slug/webhooks/:id", SubscriptionApiController, :update)
    delete("/workspaces/:workspace_slug/webhooks/:id", SubscriptionApiController, :delete)

    # Delivery logs
    get(
      "/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries",
      DeliveryApiController,
      :index
    )

    get(
      "/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries/:id",
      DeliveryApiController,
      :show
    )
  end

  # Inbound webhook receiver (HMAC signature auth, NOT Bearer token)
  scope "/api", WebhooksApi do
    pipe_through([:api_base])

    post("/workspaces/:workspace_slug/webhooks/inbound", InboundWebhookApiController, :receive)
  end
end
