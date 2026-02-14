# Entity Relationship Manager

A schema-driven graph data layer for managing entities, edges, and their relationships within tenant-isolated workspaces. Backed by Neo4j (graph operations) and PostgreSQL (schema persistence), exposed as a JSON REST API.

## Architecture

The app follows Clean Architecture with strict boundary enforcement via the `boundary` library:

```
Interface (Router, Controllers, Plugs, Views)
    |
Application (Use Cases, Behaviours)
    |
Domain (Entities, Policies, Services)
    |
Infrastructure (Repositories, Adapters, Ecto Schemas)
```

Each layer can only depend on the layer below it. Cross-layer violations are caught at compile time.

### Domain Layer

Pure business logic with no I/O or framework dependencies.

**Entities** -- value objects representing the core data model:

| Entity | Description |
|--------|-------------|
| `Entity` | A node in the graph with type, properties, and soft-delete support |
| `Edge` | A directed relationship between two entities with type and properties |
| `SchemaDefinition` | Workspace-scoped schema defining allowed entity/edge types |
| `EntityTypeDefinition` | Defines an entity type and its property specifications |
| `EdgeTypeDefinition` | Defines an edge type and its property specifications |
| `PropertyDefinition` | Defines a property's name, type, required flag, and constraints |

Supported property types: `:string`, `:integer`, `:float`, `:boolean`, `:datetime`

Supported constraints:
- String: `min_length`, `max_length`, `pattern` (regex), `enum`
- Numeric (integer/float): `min`, `max`, `enum`
- Datetime: ISO 8601 format validation

**Policies** -- pure functions enforcing business rules:

| Policy | Responsibility |
|--------|---------------|
| `AuthorizationPolicy` | Role-based access control (owner/admin/member/guest) |
| `SchemaValidationPolicy` | Validates schema structure and entity/edge conformance |
| `InputSanitizationPolicy` | Validates type names and UUID formats |
| `TraversalPolicy` | Validates traversal params (depth 1-10, direction, limit 1-500) |

**Services:**

| Service | Responsibility |
|---------|---------------|
| `PropertyValidator` | Validates property values against their definitions and constraints |

### Application Layer

Orchestrates domain logic through 19 use cases, all following the same pattern:

```elixir
UseCases.CreateEntity.execute(workspace_id, attrs, opts \\ [])
```

Every use case supports dependency injection via `opts` for testability:
- `schema_repo:` -- override the schema repository (default configured at compile time)
- `graph_repo:` -- override the graph repository (default configured at compile time)

**Use cases:**

| Category | Use Cases |
|----------|-----------|
| Schema | `GetSchema`, `UpsertSchema` |
| Entity CRUD | `CreateEntity`, `GetEntity`, `ListEntities`, `UpdateEntity`, `DeleteEntity` |
| Edge CRUD | `CreateEdge`, `GetEdge`, `ListEdges`, `UpdateEdge`, `DeleteEdge` |
| Traversal | `GetNeighbors`, `FindPaths`, `Traverse` |
| Bulk | `BulkCreateEntities`, `BulkUpdateEntities`, `BulkDeleteEntities`, `BulkCreateEdges` |

Bulk operations support `:atomic` (all-or-nothing, default) and `:partial` modes, with a max batch size of 1000.

**Behaviours:**

| Behaviour | Callbacks |
|-----------|-----------|
| `SchemaRepositoryBehaviour` | `get_schema/1`, `upsert_schema/2` |
| `GraphRepositoryBehaviour` | 19 callbacks covering CRUD, traversal, bulk, and health check |

### Infrastructure Layer

**Repositories:**

| Repository | Backing Store | Notes |
|------------|--------------|-------|
| `SchemaRepository` | PostgreSQL via Ecto | Table `entity_schemas`, optimistic locking on `version` |
| `GraphRepository` | Neo4j via Cypher | Parameterized queries, tenant isolation via `_workspace_id` |

**Adapters:**

| Adapter | Purpose |
|---------|---------|
| `Neo4jAdapter` | Thin wrapper with configurable backend (DI via config or opts) |
| `Neo4jAdapter.DefaultAdapter` | Placeholder returning `{:error, :not_configured}` until Boltx is provisioned |

**Ecto Schema:**

`SchemaDefinitionSchema` maps to the `entity_schemas` table with JSONB columns for `entity_types` and `edge_types`.

### Interface Layer

**Plugs:**

| Plug | Purpose |
|------|---------|
| `WorkspaceAuthPlug` | Extracts Bearer token, verifies API key, resolves user and workspace membership |
| `AuthorizePlug` | Checks member role against `AuthorizationPolicy` per action |
| `SecurityHeadersPlug` | Sets security headers (CSP, HSTS, X-Frame-Options, etc.) |

**Controllers:** `HealthController`, `SchemaController`, `EntityController`, `EdgeController`, `TraversalController`

**Views:** `EntityJSON`, `EdgeJSON`, `SchemaJSON`, `TraversalJSON`, `ErrorJSON`

## API Routes

All authenticated routes require a Bearer token in the `Authorization` header.

### Health

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/health` | No | Service health check |

### Schema

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/v1/workspaces/:workspace_id/schema` | Yes | Get workspace schema |
| `PUT` | `/api/v1/workspaces/:workspace_id/schema` | Yes | Create or update schema |

### Entities

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/workspaces/:workspace_id/entities` | Yes | Create entity |
| `GET` | `/api/v1/workspaces/:workspace_id/entities` | Yes | List entities (with filters) |
| `GET` | `/api/v1/workspaces/:workspace_id/entities/:id` | Yes | Get entity by ID |
| `PUT` | `/api/v1/workspaces/:workspace_id/entities/:id` | Yes | Update entity properties |
| `DELETE` | `/api/v1/workspaces/:workspace_id/entities/:id` | Yes | Soft-delete entity (cascades to edges) |
| `POST` | `/api/v1/workspaces/:workspace_id/entities/bulk` | Yes | Bulk create entities |
| `PUT` | `/api/v1/workspaces/:workspace_id/entities/bulk` | Yes | Bulk update entities |
| `DELETE` | `/api/v1/workspaces/:workspace_id/entities/bulk` | Yes | Bulk delete entities |

### Edges

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/workspaces/:workspace_id/edges` | Yes | Create edge |
| `GET` | `/api/v1/workspaces/:workspace_id/edges` | Yes | List edges (with filters) |
| `GET` | `/api/v1/workspaces/:workspace_id/edges/:id` | Yes | Get edge by ID |
| `PUT` | `/api/v1/workspaces/:workspace_id/edges/:id` | Yes | Update edge properties |
| `DELETE` | `/api/v1/workspaces/:workspace_id/edges/:id` | Yes | Soft-delete edge |
| `POST` | `/api/v1/workspaces/:workspace_id/edges/bulk` | Yes | Bulk create edges |

### Traversal

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/v1/workspaces/:workspace_id/entities/:id/neighbors` | Yes | Get neighboring entities |
| `GET` | `/api/v1/workspaces/:workspace_id/entities/:id/paths/:target_id` | Yes | Find paths between entities |
| `GET` | `/api/v1/workspaces/:workspace_id/traverse` | Yes | N-degree graph traversal |

**Traversal query parameters:**

| Parameter | Endpoints | Values | Default |
|-----------|-----------|--------|---------|
| `direction` | neighbors, traverse | `in`, `out`, `both` | `both` |
| `entity_type` | neighbors | any defined type | -- |
| `edge_type` | neighbors | any defined type | -- |
| `max_depth` | paths, traverse | 1-10 | 1 |
| `limit` | traverse, list endpoints | 1-500 | 100 |
| `offset` | list endpoints | >= 0 | 0 |
| `start_id` | traverse | UUID (required) | -- |

## Authorization

Role-based access control enforced per endpoint:

| Action | owner | admin | member | guest |
|--------|:-----:|:-----:|:------:|:-----:|
| Read schema | yes | yes | yes | yes |
| Write schema | yes | yes | no | no |
| Create entity/edge | yes | yes | yes | no |
| Read entity/edge | yes | yes | yes | yes |
| Update entity/edge | yes | yes | yes | no |
| Delete entity/edge | yes | yes | yes | no |
| Traverse | yes | yes | yes | yes |
| Bulk operations | yes | yes | yes | no |

## Public API

The `EntityRelationshipManager` module serves as the public facade, exposing 19 functions that delegate to use cases:

```elixir
# Schema
EntityRelationshipManager.get_schema(workspace_id)
EntityRelationshipManager.upsert_schema(workspace_id, attrs)

# Entity CRUD
EntityRelationshipManager.create_entity(workspace_id, attrs)
EntityRelationshipManager.get_entity(workspace_id, entity_id)
EntityRelationshipManager.list_entities(workspace_id, filters)
EntityRelationshipManager.update_entity(workspace_id, entity_id, attrs)
EntityRelationshipManager.delete_entity(workspace_id, entity_id)

# Edge CRUD
EntityRelationshipManager.create_edge(workspace_id, attrs)
EntityRelationshipManager.get_edge(workspace_id, edge_id)
EntityRelationshipManager.list_edges(workspace_id, filters)
EntityRelationshipManager.update_edge(workspace_id, edge_id, attrs)
EntityRelationshipManager.delete_edge(workspace_id, edge_id)

# Traversal
EntityRelationshipManager.get_neighbors(workspace_id, entity_id, opts)
EntityRelationshipManager.find_paths(workspace_id, source_id, target_id, opts)
EntityRelationshipManager.traverse(workspace_id, start_id: id)

# Bulk
EntityRelationshipManager.bulk_create_entities(workspace_id, entities)
EntityRelationshipManager.bulk_update_entities(workspace_id, updates)
EntityRelationshipManager.bulk_delete_entities(workspace_id, entity_ids)
EntityRelationshipManager.bulk_create_edges(workspace_id, edges)
```

All functions accept an optional trailing `opts` keyword list for dependency injection.

## Testing

The test suite uses Mox for repository mocking, keeping all use case and controller tests fast and isolated from databases.

```bash
# Run all ERM tests (excluding neo4j/database/integration)
mix test apps/entity_relationship_manager/test \
  --exclude neo4j --exclude database --exclude integration

# Run a specific test file
mix test apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/create_entity_test.exs
```

**Test breakdown:**
- 326 tests, 0 failures
- 68 excluded (tagged `neo4j`, `database`, or `integration`)
- Domain: entity structs, policies, property validator
- Application: all 19 use cases with mocked repos
- Infrastructure: repositories and adapters
- Interface: controllers, plugs, views, router
- Integration: full lifecycle and tenant isolation (requires Neo4j)

**BDD feature files** (8 files, ~146 scenarios) in `test/features/`:
- `schema_management.http.feature`
- `entity_crud.http.feature`
- `edge_crud.http.feature`
- `graph_traversal.http.feature`
- `bulk_operations.http.feature`
- `auth.http.feature`
- `error_handling.http.feature`
- `health.http.feature`

## Configuration

In `config/config.exs` or `config/runtime.exs`:

```elixir
config :entity_relationship_manager,
  ecto_repo: Jarga.Repo,
  schema_repo: EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository,
  graph_repo: EntityRelationshipManager.Infrastructure.Repositories.GraphRepository

config :entity_relationship_manager, :neo4j_adapter,
  EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter.DefaultAdapter
```

For tests, Mox mocks are configured:

```elixir
config :entity_relationship_manager,
  schema_repo: EntityRelationshipManager.Mocks.SchemaRepositoryMock,
  graph_repo: EntityRelationshipManager.Mocks.GraphRepositoryMock
```

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `:phoenix` | Web framework (router, controllers, endpoint) |
| `:jarga` | Core platform (workspaces, repo) |
| `:identity` | Authentication (API key verification) |
| `:jason` | JSON encoding/decoding |
| `:bandit` | HTTP server |
| `:boundary` | Compile-time layer boundary enforcement |
| `:mox` | Test-only mock definitions |
