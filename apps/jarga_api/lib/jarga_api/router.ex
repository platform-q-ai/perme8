defmodule JargaApi.Router do
  use JargaApi, :router

  # Shared base pipeline for all API routes — sets content type and security headers.
  # Applied before :api or :api_authenticated so new pipelines inherit these automatically.
  pipeline :api_base do
    plug(:accepts, ["json"])
    plug(JargaApi.Plugs.SecurityHeadersPlug)
  end

  # Unauthenticated API pipeline for public endpoints (e.g., health check, OpenAPI spec)
  pipeline :api do
  end

  pipeline :api_authenticated do
    plug(JargaApi.Plugs.ApiAuthPlug)
  end

  scope "/api", JargaApi do
    pipe_through([:api_base, :api_authenticated])

    get("/workspaces", WorkspaceApiController, :index)
    get("/workspaces/:slug", WorkspaceApiController, :show)

    post("/workspaces/:workspace_slug/projects", ProjectApiController, :create)
    get("/workspaces/:workspace_slug/projects/:slug", ProjectApiController, :show)

    post("/workspaces/:workspace_slug/documents", DocumentApiController, :create)
    get("/workspaces/:workspace_slug/documents/:slug", DocumentApiController, :show)
    patch("/workspaces/:workspace_slug/documents/:slug", DocumentApiController, :update)

    post(
      "/workspaces/:workspace_slug/projects/:project_slug/documents",
      DocumentApiController,
      :create
    )

    # Outbound webhook subscriptions
    resources("/workspaces/:workspace_slug/webhooks", WebhookApiController,
      only: [:create, :index, :show, :update, :delete]
    )

    # Delivery logs (nested under webhooks)
    get(
      "/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries",
      DeliveryApiController,
      :index
    )

    get(
      "/workspaces/:workspace_slug/webhooks/:webhook_id/deliveries/:id",
      DeliveryApiController,
      :show
    )

    # Inbound webhook audit logs (admin-authenticated)
    get(
      "/workspaces/:workspace_slug/webhooks/inbound/logs",
      InboundWebhookApiController,
      :logs
    )
  end

  # Inbound webhook receiver — signature-authenticated (NOT bearer token)
  scope "/api", JargaApi do
    pipe_through([:api_base])

    post(
      "/workspaces/:workspace_slug/webhooks/inbound",
      InboundWebhookApiController,
      :receive
    )
  end
end
