defmodule AgentsApi.Router do
  use AgentsApi, :router

  # Shared base pipeline for all API routes — sets content type and security headers.
  pipeline :api_base do
    plug(:accepts, ["json"])
    plug(AgentsApi.Plugs.SecurityHeadersPlug)
  end

  # Unauthenticated API pipeline for public endpoints (e.g., health check, OpenAPI spec)
  pipeline :api do
  end

  pipeline :api_authenticated do
    plug(AgentsApi.Plugs.ApiAuthPlug)
  end

  scope "/api", AgentsApi do
    pipe_through([:api_base])

    get("/health", HealthController, :show)
    get("/openapi", OpenApiController, :show)
  end

  scope "/api", AgentsApi do
    pipe_through([:api_base, :api_authenticated])

    resources("/agents", AgentApiController, only: [:index, :show, :create, :update, :delete])

    post("/agents/:id/query", AgentQueryController, :create)
    get("/agents/:id/skills", SkillApiController, :index)
  end
end
