defmodule EntityRelationshipManager do
  @moduledoc """
  Entity Relationship Manager - A schema-driven graph data layer.

  Provides workspace-scoped entity and relationship management backed by
  Neo4j (graph storage) and PostgreSQL (schema definitions). Exposes a
  JSON REST API for CRUD, traversal, and bulk operations.

  ## Dependencies

  - `Identity` - API key verification and user lookup
  - `Jarga.Workspaces` - Workspace membership and role verification

  ## Exported Types

  - `EntityRelationshipManager.Domain.Entities.Entity`
  - `EntityRelationshipManager.Domain.Entities.Edge`
  - `EntityRelationshipManager.Domain.Entities.SchemaDefinition`
  """

  use Boundary,
    deps: [
      Identity,
      Jarga.Workspaces,
      Jarga.Repo
    ],
    exports: [
      Endpoint
    ]

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: EntityRelationshipManager.Endpoint,
        router: EntityRelationshipManager.Router,
        statics: []
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/router/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
