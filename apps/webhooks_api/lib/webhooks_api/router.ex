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

    # Subscription CRUD
    get("/workspaces/:workspace_slug/webhooks", SubscriptionController, :index)
    post("/workspaces/:workspace_slug/webhooks", SubscriptionController, :create)
    get("/workspaces/:workspace_slug/webhooks/:id", SubscriptionController, :show)
    patch("/workspaces/:workspace_slug/webhooks/:id", SubscriptionController, :update)
    delete("/workspaces/:workspace_slug/webhooks/:id", SubscriptionController, :delete)

    # Delivery logs
    get(
      "/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries",
      DeliveryController,
      :index
    )

    get(
      "/workspaces/:workspace_slug/webhooks/:subscription_id/deliveries/:id",
      DeliveryController,
      :show
    )

    # Inbound webhook audit logs (authenticated)
    get("/workspaces/:workspace_slug/webhooks/inbound/logs", InboundLogController, :index)
  end

  # Inbound webhook receiver (HMAC signature auth, NOT Bearer token)
  scope "/api", WebhooksApi do
    pipe_through([:api_base])

    post("/workspaces/:workspace_slug/webhooks/inbound", InboundWebhookController, :receive)
  end
end
