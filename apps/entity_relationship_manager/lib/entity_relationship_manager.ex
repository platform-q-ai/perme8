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
    top_level?: true,
    deps: [
      Identity,
      Jarga.Workspaces,
      Jarga.Repo
    ],
    exports: [
      Endpoint,
      {Domain.Entities.SchemaDefinition, []},
      {Domain.Entities.EntityTypeDefinition, []},
      {Domain.Entities.EdgeTypeDefinition, []},
      {Domain.Entities.PropertyDefinition, []},
      {Domain.Entities.Entity, []},
      {Domain.Entities.Edge, []},
      # Exported for Infrastructure layer to implement
      {Application.Behaviours.SchemaRepositoryBehaviour, []},
      {Application.Behaviours.GraphRepositoryBehaviour, []}
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

  # ---------------------------------------------------------------------------
  # Public Facade — thin delegation to use cases
  # ---------------------------------------------------------------------------

  alias EntityRelationshipManager.Application.UseCases

  # Schema

  @doc "Retrieves the schema definition for a workspace."
  def get_schema(workspace_id, opts \\ []) do
    UseCases.GetSchema.execute(workspace_id, opts)
  end

  @doc "Creates or updates a workspace's schema definition."
  def upsert_schema(workspace_id, attrs, opts \\ []) do
    UseCases.UpsertSchema.execute(workspace_id, attrs, opts)
  end

  # Entity CRUD

  @doc "Creates an entity in the workspace graph."
  def create_entity(workspace_id, attrs, opts \\ []) do
    UseCases.CreateEntity.execute(workspace_id, attrs, opts)
  end

  @doc "Retrieves an entity by ID."
  def get_entity(workspace_id, entity_id, opts \\ []) do
    UseCases.GetEntity.execute(workspace_id, entity_id, opts)
  end

  @doc "Lists entities with optional filters."
  def list_entities(workspace_id, filters \\ %{}, opts \\ []) do
    UseCases.ListEntities.execute(workspace_id, filters, opts)
  end

  @doc "Updates an entity's properties."
  def update_entity(workspace_id, entity_id, attrs, opts \\ []) do
    UseCases.UpdateEntity.execute(workspace_id, entity_id, attrs, opts)
  end

  @doc "Soft-deletes an entity by ID."
  def delete_entity(workspace_id, entity_id, opts \\ []) do
    UseCases.DeleteEntity.execute(workspace_id, entity_id, opts)
  end

  # Edge CRUD

  @doc "Creates an edge (relationship) in the workspace graph."
  def create_edge(workspace_id, attrs, opts \\ []) do
    UseCases.CreateEdge.execute(workspace_id, attrs, opts)
  end

  @doc "Retrieves an edge by ID."
  def get_edge(workspace_id, edge_id, opts \\ []) do
    UseCases.GetEdge.execute(workspace_id, edge_id, opts)
  end

  @doc "Lists edges with optional filters."
  def list_edges(workspace_id, filters \\ %{}, opts \\ []) do
    UseCases.ListEdges.execute(workspace_id, filters, opts)
  end

  @doc "Updates an edge's properties."
  def update_edge(workspace_id, edge_id, attrs, opts \\ []) do
    UseCases.UpdateEdge.execute(workspace_id, edge_id, attrs, opts)
  end

  @doc "Soft-deletes an edge by ID."
  def delete_edge(workspace_id, edge_id, opts \\ []) do
    UseCases.DeleteEdge.execute(workspace_id, edge_id, opts)
  end

  # Traversal

  @doc "Gets neighboring entities of the given entity."
  def get_neighbors(workspace_id, entity_id, opts \\ []) do
    UseCases.GetNeighbors.execute(workspace_id, entity_id, opts)
  end

  @doc "Finds paths between source and target entities."
  def find_paths(workspace_id, source_id, target_id, opts \\ []) do
    UseCases.FindPaths.execute(workspace_id, source_id, target_id, opts)
  end

  @doc "Traverses the graph from a starting entity."
  def traverse(workspace_id, opts \\ []) do
    {start_id, opts} = Keyword.pop!(opts, :start_id)
    UseCases.Traverse.execute(workspace_id, start_id, opts)
  end

  # Bulk

  @doc "Bulk-creates entities in the workspace graph."
  def bulk_create_entities(workspace_id, entities, opts \\ []) do
    UseCases.BulkCreateEntities.execute(workspace_id, entities, opts)
  end

  @doc "Bulk-updates entities in the workspace graph."
  def bulk_update_entities(workspace_id, updates, opts \\ []) do
    UseCases.BulkUpdateEntities.execute(workspace_id, updates, opts)
  end

  @doc "Bulk soft-deletes entities by their IDs."
  def bulk_delete_entities(workspace_id, entity_ids, opts \\ []) do
    UseCases.BulkDeleteEntities.execute(workspace_id, entity_ids, opts)
  end

  @doc "Bulk-creates edges in the workspace graph."
  def bulk_create_edges(workspace_id, edges, opts \\ []) do
    UseCases.BulkCreateEdges.execute(workspace_id, edges, opts)
  end

  @doc """
  When used, dispatch to the appropriate controller/router/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
