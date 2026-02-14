defmodule EntityRelationshipManager.Router do
  use EntityRelationshipManager, :router

  pipeline :api_base do
    plug(:accepts, ["json"])
  end

  # Health check (unauthenticated)
  scope "/", EntityRelationshipManager do
    pipe_through([:api_base])
    get("/health", HealthController, :show)
  end
end
