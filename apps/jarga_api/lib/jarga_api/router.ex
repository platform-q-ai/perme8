defmodule JargaApi.Router do
  use JargaApi, :router

  # Unauthenticated API pipeline for public endpoints (e.g., health check, OpenAPI spec)
  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_authenticated do
    plug(:accepts, ["json"])
    plug(JargaApi.Plugs.ApiAuthPlug)
  end

  scope "/api", JargaApi do
    pipe_through(:api_authenticated)

    get("/workspaces", WorkspaceApiController, :index)
    get("/workspaces/:slug", WorkspaceApiController, :show)

    post("/workspaces/:workspace_slug/projects", ProjectApiController, :create)
    get("/workspaces/:workspace_slug/projects/:slug", ProjectApiController, :show)
  end
end
