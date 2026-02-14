defmodule EntityRelationshipManager.Router do
  use EntityRelationshipManager, :router

  pipeline :api_base do
    plug(:accepts, ["json"])
    plug(EntityRelationshipManager.Plugs.SecurityHeadersPlug)
  end

  pipeline :api_authenticated do
    plug(EntityRelationshipManager.Plugs.WorkspaceAuthPlug)
  end

  # Health check (unauthenticated)
  scope "/", EntityRelationshipManager do
    pipe_through([:api_base])
    get("/health", HealthController, :show)
  end

  # Workspace-scoped API routes
  scope "/api/v1/workspaces/:workspace_id", EntityRelationshipManager do
    pipe_through([:api_base, :api_authenticated])

    # Schema
    get("/schema", SchemaController, :show)
    put("/schema", SchemaController, :update)

    # Entities - bulk routes BEFORE :id routes
    post("/entities/bulk", EntityController, :bulk_create)
    put("/entities/bulk", EntityController, :bulk_update)
    delete("/entities/bulk", EntityController, :bulk_delete)
    post("/entities", EntityController, :create)
    get("/entities", EntityController, :index)
    get("/entities/:id", EntityController, :show)
    put("/entities/:id", EntityController, :update)
    delete("/entities/:id", EntityController, :delete)

    # Traversal - before edges to avoid route conflicts
    get("/entities/:id/neighbors", TraversalController, :neighbors)
    get("/entities/:id/paths/:target_id", TraversalController, :paths)
    get("/traverse", TraversalController, :traverse)

    # Edges - bulk routes BEFORE :id routes
    post("/edges/bulk", EdgeController, :bulk_create)
    post("/edges", EdgeController, :create)
    get("/edges", EdgeController, :index)
    get("/edges/:id", EdgeController, :show)
    put("/edges/:id", EdgeController, :update)
    delete("/edges/:id", EdgeController, :delete)
  end
end
