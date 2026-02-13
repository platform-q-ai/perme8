# Product Requirements Document: Entity Relationship Manager

## 1. Executive Summary

**Feature Name**: Entity Relationship Manager (ERM)

**Problem Statement**: The Jarga platform lacks a generic, schema-driven graph data layer for modelling arbitrary entities and their relationships. Teams need the ability to define custom data models -- business objects, knowledge graphs, asset maps -- and manage them through a structured API backed by a graph database, without requiring code changes or redeployments.

**Business Value**: Provides a foundational, reusable graph data service that enables:
- Custom business relationship modelling per workspace (e.g., "Company employs Person", "Service depends on Infrastructure")
- A queryable knowledge graph for AI agents to reason about structured relationships
- A general-purpose entity store that other Jarga features can build upon

**Target Users**:
- **API consumers**: Other Jarga umbrella apps (`jarga`, `jarga_web`, `jarga_api`) calling the ERM as an internal dependency
- **External integrators**: Third-party systems interacting via the ERM's HTTP API
- **AI agents/LLMs**: Querying and manipulating the graph programmatically for reasoning
- **End users** (future): Via an eventual graph visualization/editor UI

---

## 2. User Stories

**Primary User Story**:
```
As a workspace administrator,
I want to define what entity types (with properties) and relationship types are valid in my workspace,
so that my team can create and manage structured graph data that conforms to our domain model.
```

**Additional User Stories**:

- As an API consumer, I want to create entities and relationships that conform to my workspace's schema, so that the graph always contains valid, well-structured data.
- As an API consumer, I want to traverse relationships between entities (paths, neighbors, N-degree connections), so that I can discover how things are connected.
- As an AI agent, I want to query the entity graph for a workspace, so that I can reason about relationships and provide context-aware responses.
- As a workspace admin, I want to update the schema (add new entity types, properties, or edge types) without downtime, so that the data model can evolve with our needs.
- As an API consumer, I want to perform bulk operations (create/update/delete multiple entities or edges), so that I can efficiently import or transform data.
- As an API consumer, I want soft-deleted entities to be recoverable, so that accidental deletions don't cause data loss.

---

## 3. Functional Requirements

### Core Functionality

**Must Have (P0)** - Critical for MVP:

1. **Schema Management** (stored in PostgreSQL)
   - Define valid entity types per workspace (e.g., `Person`, `Company`, `Service`)
   - Define typed properties per entity type with validation constraints (required/optional, min/max, regex, enum values)
   - Define valid edge/relationship types (e.g., `EMPLOYS`, `DEPENDS_ON`, `OWNS`)
   - Schema is per-workspace -- each workspace defines its own valid types
   - Property types: string, integer, float, boolean, datetime (start simple, evolve later)

2. **Entity CRUD** (stored in Neo4j)
   - Create entities of a configured type with validated properties
   - Read entities by ID, by type, or by property filters
   - Update entity properties (validated against schema)
   - Soft-delete entities (mark as archived with `deleted_at` timestamp)
   - All entities scoped to a workspace via tenant label/property in Neo4j

3. **Edge/Relationship CRUD** (stored in Neo4j)
   - Create named relationships between entities (must be a configured edge type)
   - Edges optionally carry their own properties
   - Read relationships for an entity (inbound, outbound, or both)
   - Delete relationships (soft-delete with `deleted_at`)

4. **Path Traversal & Query**
   - Find direct neighbors of an entity (1-degree)
   - Find paths between two entities
   - N-degree connection discovery (configurable depth limit)
   - Filter traversal by entity type and/or edge type

5. **Bulk Operations**
   - Bulk create entities (validated against schema)
   - Bulk create edges
   - Bulk update entities
   - Bulk soft-delete

6. **Authentication & Authorization**
   - Authenticate via Identity app (session tokens and API keys)
   - Authorize using existing workspace roles (owner/admin/member/guest)
   - All operations scoped to a workspace the caller has access to

7. **Multi-Tenancy**
   - Shared Neo4j database with workspace-scoped labels/properties on all nodes and edges
   - Every query filtered by workspace context -- no cross-tenant data leakage

**Should Have (P1)** - Important but not blocking MVP:

1. **Schema versioning** - Track changes to workspace schemas over time
2. **Edge direction constraints** - Define which entity types can be source/target for an edge type (e.g., `EMPLOYS` only valid from `Company` to `Person`)
3. **Property indexing hints** - Mark properties that should be indexed in Neo4j for query performance

**Nice to Have (P2)** - Future enhancements:

1. **Graph analytics** - Centrality, clustering, shortest path algorithms
2. **Event streaming** - Publish entity/edge change events via PubSub for real-time consumers
3. **Import/export** - CSV, JSON, or GraphML import/export of subgraphs
4. **Property type extensions** - Lists, nested objects, references to other entities

### User Workflows

**Workflow 1: Schema Definition**
1. Admin authenticates via Identity (API key or session)
2. Admin creates/updates a schema definition for their workspace
3. System validates the schema structure (valid types, no conflicts)
4. System persists the schema in PostgreSQL
5. Schema is immediately available for entity/edge validation

**Workflow 2: Entity & Relationship Management**
1. Consumer authenticates and provides workspace context
2. Consumer creates entities, specifying type and properties
3. System validates entity against workspace schema
4. System persists entity in Neo4j with workspace scoping
5. Consumer creates edges between entities
6. System validates edge type is configured and entities exist
7. Consumer queries/traverses the graph

**Workflow 3: Bulk Import**
1. Consumer authenticates and provides workspace context
2. Consumer submits a batch of entities and/or edges
3. System validates all items against schema
4. System reports validation errors (partial success or all-or-nothing, configurable)
5. System persists valid items in Neo4j

### Data Requirements

**Schema Definitions (PostgreSQL)**:

| Field | Type | Required? | Validation Rules | Notes |
|-------|------|-----------|------------------|-------|
| id | UUID | Yes | Auto-generated | Primary key |
| workspace_id | UUID | Yes | Must reference valid workspace | Foreign key to workspaces table |
| entity_types | JSONB | Yes | Array of type definitions | Each with name + property definitions |
| edge_types | JSONB | Yes | Array of edge type definitions | Name, optional property definitions |
| version | integer | Yes | Auto-incremented | Schema version tracking |
| created_at | datetime | Yes | Auto-set | |
| updated_at | datetime | Yes | Auto-set | |

**Entity Type Definition** (within JSONB):
```json
{
  "name": "Person",
  "properties": [
    {
      "name": "full_name",
      "type": "string",
      "required": true,
      "constraints": { "min_length": 1, "max_length": 255 }
    },
    {
      "name": "email",
      "type": "string",
      "required": false,
      "constraints": { "pattern": "^[^@]+@[^@]+$" }
    },
    {
      "name": "age",
      "type": "integer",
      "required": false,
      "constraints": { "min": 0, "max": 200 }
    }
  ]
}
```

**Edge Type Definition** (within JSONB):
```json
{
  "name": "EMPLOYS",
  "properties": [
    {
      "name": "since",
      "type": "datetime",
      "required": false
    },
    {
      "name": "role",
      "type": "string",
      "required": false,
      "constraints": { "enum": ["full-time", "part-time", "contractor"] }
    }
  ]
}
```

**Neo4j Node Structure**:
- Label: entity type name (e.g., `:Person`, `:Company`)
- Additional label: `:Entity` (common label for all ERM nodes)
- Properties:
  - `_id`: UUID (application-generated)
  - `_workspace_id`: UUID (tenant scoping)
  - `_type`: string (entity type name, redundant with label for query convenience)
  - `_created_at`: datetime
  - `_updated_at`: datetime
  - `_deleted_at`: datetime | null (soft delete)
  - User-defined properties from schema

**Neo4j Relationship Structure**:
- Type: edge type name (e.g., `EMPLOYS`, `DEPENDS_ON`)
- Properties:
  - `_id`: UUID
  - `_workspace_id`: UUID
  - `_created_at`: datetime
  - `_updated_at`: datetime
  - `_deleted_at`: datetime | null
  - User-defined properties from schema

---

## 4. Technical Requirements

### Architecture Considerations

**Affected Layers**:
- [x] **Domain Layer** - Entity, Edge, and Schema domain entities; validation policies; traversal logic
- [x] **Application Layer** - Use cases for CRUD, traversal, schema management; repository behaviours
- [x] **Infrastructure Layer** - Neo4j adapter/driver, PostgreSQL schema storage, Bolt protocol connection management
- [x] **Interface Layer** - Phoenix JSON API endpoint on port 4005

**Technology Stack**:
- **Backend**: New umbrella app `entity_relationship_manager` (Elixir/Phoenix)
- **Graph Database**: Neo4j (via Bolt protocol, using `bolt_sips` or `boltx` Elixir driver)
- **Schema Storage**: PostgreSQL via Ecto (for schema definitions, leveraging existing `Jarga.Repo` or own repo)
- **API**: JSON REST API served by its own Phoenix endpoint
- **Authentication**: Delegates to `Identity` app (API key verification, session token validation)

### Integration Points

**Existing Systems**:

| System/Context | Integration Type | Purpose | Notes |
|----------------|------------------|---------|-------|
| Identity | Read | Authentication - verify API keys and session tokens | Use `Identity.verify_api_key/1`, session plugs |
| Jarga.Workspaces | Read | Verify workspace membership and roles | Use `Jarga.Workspaces.verify_membership/2` |
| Neo4j | Read/Write | Primary graph data storage | New external dependency |
| PostgreSQL (Ecto) | Read/Write | Schema definition storage | Via existing or new Ecto Repo |

**External Services**:

| Service | API/SDK | Authentication | Rate Limits | Error Handling |
|---------|---------|----------------|-------------|----------------|
| Neo4j | Bolt protocol (Elixir driver) | Username/password or token | Connection pool limits | Retry with backoff, circuit breaker |

### Performance Requirements

- **Response Time**: < 200ms for single entity/edge CRUD; < 500ms for traversal queries (depth <= 3)
- **Throughput**: Handle 100 concurrent API requests per workspace
- **Data Volume**: Support ~10,000 entities and ~50,000 edges per workspace
- **Bulk Operations**: Process batches of up to 1,000 items within 5 seconds

### Security Requirements

**Authentication**:
- [x] Requires user login (session token via Identity)
- [x] API token authentication (API keys via Identity)

**Authorization**:
- [x] Role-based access control using workspace roles:
  - **Owner/Admin**: Full CRUD on entities, edges, and schema definitions
  - **Member**: Create/read/update entities and edges; read schema definitions
  - **Guest**: Read-only access to entities, edges, and schema
- [x] Team/workspace-based permissions -- all data scoped to workspace

**Data Privacy**:
- [x] Requires encryption in transit (HTTPS)
- [ ] Contains PII -- depends on what users store; schema should support marking properties as sensitive (future)
- [x] Tenant isolation -- workspace-scoped queries prevent cross-tenant access

**Input Validation**:
- All entity properties validated against schema constraints before persistence
- Entity type names and edge type names validated (alphanumeric, underscore, no SQL/Cypher injection)
- Cypher query parameters always parameterized (never string-interpolated)
- UUID format validation on all ID fields
- Depth limits on traversal queries to prevent resource exhaustion

---

## 5. Non-Functional Requirements

### Scalability
- Neo4j connection pooling with configurable pool size per environment
- Stateless API design -- horizontal scaling of Phoenix nodes
- Consider Neo4j read replicas for read-heavy workloads (future)

### Reliability
- Graceful degradation if Neo4j is unavailable (return 503, don't crash)
- Circuit breaker pattern for Neo4j connections
- Health check endpoint for Neo4j connectivity

### Maintainability
- Clean Architecture layers with Boundary enforcement
- Behaviour-based abstractions for Neo4j adapter (testable with mocks)
- Comprehensive test coverage: unit tests for domain/application, integration tests for Neo4j operations

### Observability
- Telemetry events for all Neo4j operations (query time, result count)
- Structured logging for schema changes, bulk operations, and errors
- Health check endpoint: `GET /health` returning Neo4j connection status

---

## 6. User Interface Requirements

**N/A for MVP** -- this is a headless app. No UI.

Future considerations:
- Graph visualization component (force-directed layout)
- Schema editor UI
- Entity/edge CRUD forms
- Traversal explorer

---

## 7. Edge Cases & Error Handling

### Known Edge Cases

**Edge Case 1**: Schema change invalidates existing entities
- **Expected Behavior**: Schema changes do not retroactively invalidate existing entities. New validations only apply to new creates/updates. A separate "validate existing data" endpoint can report non-conforming entities.
- **Rationale**: Avoids breaking existing data on schema evolution.

**Edge Case 2**: Deleting an entity that has edges
- **Expected Behavior**: Soft-delete the entity AND soft-delete all its edges (cascade soft-delete). Return the count of affected edges in the response.
- **Rationale**: Orphaned edges create inconsistency.

**Edge Case 3**: Circular relationships in traversal
- **Expected Behavior**: Traversal detects cycles and does not revisit nodes. Configurable max depth (default: 5, max: 10).
- **Rationale**: Prevent infinite loops and resource exhaustion.

**Edge Case 4**: Bulk operation with partial failures
- **Expected Behavior**: Support two modes:
  - `atomic`: All-or-nothing -- if any item fails validation, reject the entire batch
  - `partial`: Process valid items, return errors for invalid ones with their indices
- **Rationale**: Different use cases need different guarantees.

**Edge Case 5**: Concurrent schema modification
- **Expected Behavior**: Optimistic locking on schema version. If two admins modify the schema concurrently, the second write fails with a conflict error.
- **Rationale**: Prevent lost updates.

### Error Scenarios

**Error: Neo4j connection failure**
- **API Response**: 503 Service Unavailable with `{"error": "graph_unavailable", "message": "Graph database is temporarily unavailable"}`
- **Recovery**: Circuit breaker with exponential backoff
- **Logging**: Error-level log with connection details (no credentials)

**Error: Schema validation failure**
- **API Response**: 422 Unprocessable Entity with detailed validation errors per property
- **Recovery**: Client corrects payload and retries
- **Format**: `{"errors": [{"field": "age", "message": "must be >= 0", "constraint": "min"}]}`

**Error: Entity not found**
- **API Response**: 404 Not Found
- **Note**: Returns 404 for entities outside the caller's workspace (not 403) to avoid leaking existence information

**Error: Unauthorized workspace access**
- **API Response**: 403 Forbidden

### Boundary Conditions
- **Empty state**: Workspace with no schema defined returns 422 on entity creation with "no schema configured"
- **Maximum limits**: Configurable per-workspace limits on entity count (default: 50,000) and edge count (default: 200,000)
- **Concurrent access**: Neo4j handles concurrent writes natively; application-level optimistic locking on schema modifications

---

## 8. Validation & Testing Criteria

### Acceptance Criteria

- [ ] **AC1**: A workspace admin can define a schema with entity types, properties (with constraints), and edge types -- Verify by: creating a schema via API and reading it back
- [ ] **AC2**: An API consumer can create an entity that conforms to the workspace schema -- Verify by: POST entity, confirm 201, GET entity back with all properties
- [ ] **AC3**: Creating an entity that violates the schema returns a 422 with detailed errors -- Verify by: submitting invalid properties and checking error response
- [ ] **AC4**: An API consumer can create edges between existing entities -- Verify by: POST edge, confirm 201, query entity neighbors
- [ ] **AC5**: Traversal returns correct paths between connected entities -- Verify by: creating a known graph topology and querying paths
- [ ] **AC6**: All operations are workspace-scoped -- Verify by: attempting to access entities from another workspace, expecting 404
- [ ] **AC7**: Workspace roles are enforced -- Verify by: guest attempting write operations, expecting 403
- [ ] **AC8**: Soft-delete marks entities/edges with `deleted_at` and excludes them from queries by default -- Verify by: deleting an entity, confirming it disappears from listings but exists with `?include_deleted=true`
- [ ] **AC9**: Bulk create processes up to 1,000 entities within 5 seconds -- Verify by: submitting a batch and measuring response time
- [ ] **AC10**: Neo4j unavailability returns 503 without crashing the application -- Verify by: stopping Neo4j and making API requests

### Test Scenarios

**Happy Path Tests**:
1. **Scenario**: Full lifecycle -- define schema, create entities, create edges, traverse, soft-delete
   **Expected Result**: All operations succeed with correct responses

2. **Scenario**: Bulk import 500 entities and 1,000 edges
   **Expected Result**: All created successfully, queryable immediately

**Edge Case Tests**:
1. **Scenario**: Create entity with missing required property
   **Expected Result**: 422 with specific validation error

2. **Scenario**: Traverse cyclic graph with depth limit
   **Expected Result**: Returns paths without infinite loops, respects depth limit

**Security Tests**:
1. **Scenario**: API consumer with workspace A credentials attempts to read workspace B entities
   **Expected Result**: 404 (not 403)

2. **Scenario**: Guest role attempts to create an entity
   **Expected Result**: 403 Forbidden

---

## 9. Dependencies & Assumptions

### Dependencies

**Internal Dependencies**:
- `identity` app -- Authentication (API keys, sessions) -- Stable, in production -- Required
- `jarga` app -- Workspace membership verification -- Stable, in production -- Required for role checks

**External Dependencies**:
- Neo4j database (v5+) -- Self-hosted or managed (Aura) -- Requires new infrastructure provisioning
- Elixir Neo4j driver (`boltx` or `bolt_sips`) -- Open source -- Evaluate maturity and maintenance status

**Data Dependencies**:
- New PostgreSQL migration for `entity_schemas` table
- Neo4j database provisioned and accessible from application

### Assumptions

- **Assumption 1**: A single shared Neo4j instance is sufficient for the medium-scale target (thousands of entities per workspace).
  - **Impact if wrong**: May need per-tenant Neo4j instances or sharding -- significant architectural change.

- **Assumption 2**: The existing Identity auth mechanisms (API keys and session tokens) are sufficient for ERM authentication -- no new auth flows needed.
  - **Impact if wrong**: Would need to extend Identity with new grant types.

- **Assumption 3**: Workspace membership/roles from `Jarga.Workspaces` can be queried without performance issues for every ERM API request.
  - **Impact if wrong**: May need to cache membership/role data or use a lighter verification mechanism.

### Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| Neo4j Elixir driver immaturity | Medium | High | Evaluate `boltx` and `bolt_sips` early; fallback to raw Bolt protocol if needed |
| Neo4j operational complexity | Medium | Medium | Start with managed Neo4j (Aura) for dev/staging; document ops procedures |
| Cross-database consistency (PG + Neo4j) | Medium | High | Schema definitions are source of truth in PG; Neo4j data is eventually consistent; no distributed transactions |
| Cypher injection via user-supplied values | Low | High | Always use parameterized queries; never interpolate user input into Cypher strings |

---

## 10. Success Metrics

### Technical Metrics

- **Performance**: p95 latency < 200ms for single-entity operations; < 500ms for traversals
- **Reliability**: Error rate < 0.1% (excluding client validation errors)
- **Test Coverage**: > 90% for domain and application layers

### Adoption Metrics

- **Internal**: At least one other Jarga feature consumes the ERM within 3 months of launch
- **External**: At least 5 workspaces have defined schemas and created entities within first month

---

## 11. Out of Scope

- Web UI / graph visualization (headless only for MVP)
- Graph analytics algorithms (centrality, PageRank, community detection)
- Real-time event streaming / PubSub notifications on entity changes
- Import/export (CSV, GraphML, JSON-LD)
- Full-text search across entity properties
- Property types beyond primitives (no lists, nested objects, or entity references in MVP)
- Edge direction constraints (which entity types can connect via which edge types)
- Per-entity or per-edge ACLs (workspace roles only)

**Rationale**: Keep MVP focused on core CRUD, traversal, and schema management. These features are valuable but can be layered on incrementally.

---

## 12. Future Considerations

- Graph visualization UI -- Interactive force-directed graph editor in LiveView
- Event streaming -- Publish entity/edge mutations to PubSub for real-time consumers
- Edge direction constraints -- Schema-level rules for valid source/target entity types per edge
- Advanced property types -- Lists, nested objects, entity references
- Graph analytics -- Expose Neo4j graph algorithms (shortest path, centrality, community detection)
- Import/export -- Bulk data interchange in standard graph formats
- Schema migration tooling -- Tools to evolve schemas and backfill/validate existing data
- Property indexing configuration -- Schema-level hints for Neo4j index creation
- Sensitive property flagging -- Mark PII properties for audit and compliance

---

## 13. Codebase Context

### Existing Patterns

**Similar Features**:
- `Identity` app -- Clean Architecture umbrella app with own endpoint, facade, domain/application/infrastructure layers (`apps/identity/`)
- `Jarga.Workspaces` -- Multi-tenancy model with workspace membership and role-based access (`apps/jarga/lib/workspaces/`)
- `JargaApi` -- API key authentication and workspace-scoped REST API (`apps/jarga_api/`)

**Reusable Components**:
- `Identity` facade -- API key verification, session token management (`apps/identity/lib/identity.ex`)
- `IdentityWeb.Plugs.UserAuth` -- Auth plugs reusable in new endpoint (`apps/identity/lib/identity_web/plugs/user_auth.ex`)
- `Jarga.Workspaces.verify_membership/2` -- Workspace membership verification
- `Jarga.Workspaces.Application.Policies.PermissionsPolicy` -- Role-based permission checks

### Affected Boundaries (Phoenix Contexts)

| Context | Why Affected? | Changes Needed | Complexity |
|---------|---------------|----------------|------------|
| Identity | Authentication dependency | Read-only -- use existing facade | Low |
| Jarga.Workspaces | Authorization dependency | Read-only -- use existing membership/role checks | Low |
| EntityRelationshipManager (new) | New bounded context | Full implementation | High |

### Available Infrastructure

**Existing Services/Modules**:
- `Identity` facade -- Can leverage for all auth needs
- `Jarga.Workspaces` -- Can leverage for workspace scoping and role verification
- Ecto/PostgreSQL -- Can leverage for schema definition storage (new migration)
- Boundary enforcement -- Must configure for new app

**Database Schema**:
- New `entity_schemas` table in PostgreSQL
- New Neo4j database/instance (external)

**Authentication/Authorization**:
- Full auth stack available via `Identity` app -- no new auth work needed

### Integration Points

**Features This Connects To**:
- `Identity` -- Authentication facade (`apps/identity/lib/identity.ex`)
- `Jarga.Workspaces` -- Workspace membership and roles (`apps/jarga/lib/workspaces.ex`)
- `JargaApi` -- Pattern reference for API key auth in a standalone endpoint (`apps/jarga_api/`)

---

## 14. API Surface

### Endpoint: `EntityRelationshipManagerWeb.Endpoint` (port 4005)

All routes prefixed with `/api/v1/workspaces/:workspace_id/`.

### Schema Management

```
GET    /api/v1/workspaces/:workspace_id/schema
PUT    /api/v1/workspaces/:workspace_id/schema
```

### Entity Operations

```
POST   /api/v1/workspaces/:workspace_id/entities                  # Create entity
GET    /api/v1/workspaces/:workspace_id/entities                  # List entities (filterable by type, properties)
GET    /api/v1/workspaces/:workspace_id/entities/:id              # Get entity
PUT    /api/v1/workspaces/:workspace_id/entities/:id              # Update entity
DELETE /api/v1/workspaces/:workspace_id/entities/:id              # Soft-delete entity

POST   /api/v1/workspaces/:workspace_id/entities/bulk             # Bulk create
PUT    /api/v1/workspaces/:workspace_id/entities/bulk             # Bulk update
DELETE /api/v1/workspaces/:workspace_id/entities/bulk             # Bulk soft-delete
```

### Edge/Relationship Operations

```
POST   /api/v1/workspaces/:workspace_id/edges                    # Create edge
GET    /api/v1/workspaces/:workspace_id/edges                    # List edges (filterable)
GET    /api/v1/workspaces/:workspace_id/edges/:id                # Get edge
PUT    /api/v1/workspaces/:workspace_id/edges/:id                # Update edge properties
DELETE /api/v1/workspaces/:workspace_id/edges/:id                # Soft-delete edge

POST   /api/v1/workspaces/:workspace_id/edges/bulk               # Bulk create edges
```

### Traversal / Query

```
GET    /api/v1/workspaces/:workspace_id/entities/:id/neighbors   # Direct neighbors
GET    /api/v1/workspaces/:workspace_id/entities/:id/paths/:target_id  # Paths between two entities
GET    /api/v1/workspaces/:workspace_id/traverse                 # N-degree traversal from a starting entity
```

### System

```
GET    /health                                                    # Health check (Neo4j connectivity)
```

### Query Parameters (common)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | string | - | Filter by entity/edge type |
| `include_deleted` | boolean | false | Include soft-deleted items |
| `depth` | integer | 1 | Traversal depth (max: 10) |
| `direction` | string | "both" | Edge direction: "in", "out", "both" |
| `limit` | integer | 50 | Pagination limit (max: 500) |
| `offset` | integer | 0 | Pagination offset |
| `mode` | string | "atomic" | Bulk operation mode: "atomic" or "partial" |

---

## 15. Umbrella App Structure

```
apps/entity_relationship_manager/
  lib/
    entity_relationship_manager.ex                    # Public facade
    entity_relationship_manager/
      domain/
        entities/
          entity.ex                                   # Graph entity domain object
          edge.ex                                     # Graph edge domain object
          schema_definition.ex                        # Schema config domain object
          property_definition.ex                      # Property config value object
        policies/
          schema_validation_policy.ex                 # Validates entities/edges against schema
          authorization_policy.ex                     # Role-based access checks
          traversal_policy.ex                         # Depth limits, cycle detection
        services/
          property_validator.ex                       # Type checking + constraint validation
      application/
        behaviours/
          graph_repository_behaviour.ex               # Neo4j abstraction
          schema_repository_behaviour.ex              # Schema storage abstraction
        use_cases/
          # Schema
          get_schema.ex
          upsert_schema.ex
          # Entities
          create_entity.ex
          get_entity.ex
          list_entities.ex
          update_entity.ex
          delete_entity.ex
          bulk_create_entities.ex
          bulk_update_entities.ex
          bulk_delete_entities.ex
          # Edges
          create_edge.ex
          get_edge.ex
          list_edges.ex
          update_edge.ex
          delete_edge.ex
          bulk_create_edges.ex
          # Traversal
          get_neighbors.ex
          find_paths.ex
          traverse.ex
      infrastructure/
        schemas/
          schema_definition_schema.ex                 # Ecto schema for PostgreSQL
        repositories/
          schema_repository.ex                        # Ecto-based schema storage
          graph_repository.ex                         # Neo4j-based entity/edge storage
        adapters/
          neo4j_adapter.ex                            # Bolt protocol driver wrapper
          neo4j_connection_pool.ex                    # Connection pool management
    entity_relationship_manager_web.ex                # Web module helpers
    entity_relationship_manager_web/
      endpoint.ex                                     # Phoenix endpoint (port 4005)
      router.ex                                       # API routes
      telemetry.ex
      plugs/
        workspace_auth_plug.ex                        # Auth + workspace scoping plug
      controllers/
        schema_controller.ex
        entity_controller.ex
        edge_controller.ex
        traversal_controller.ex
        health_controller.ex
      views/
        entity_json.ex
        edge_json.ex
        schema_json.ex
        error_json.ex
  test/
    entity_relationship_manager/
      domain/
      application/
      infrastructure/
    entity_relationship_manager_web/
      controllers/
      plugs/
    support/
      fixtures.ex
      neo4j_sandbox.ex                               # Test isolation for Neo4j
    test_helper.exs
  mix.exs
```

### Dependencies in `mix.exs`

```elixir
defp deps do
  [
    {:identity, in_umbrella: true},
    {:jarga, in_umbrella: true},
    {:phoenix, "~> 1.8"},
    {:bandit, "~> 1.5"},
    {:jason, "~> 1.2"},
    {:boltx, "~> 0.1"},           # Neo4j Bolt driver (evaluate vs bolt_sips)
    {:ecto_sql, "~> 3.10"},       # For schema definitions in PostgreSQL
    {:boundary, "~> 0.10"},
    {:gettext, "~> 1.0"}
  ]
end
```

### Dependency Graph

```
                    +-----------+
                    |  identity |
                    |  (auth)   |
                    +-----+-----+
                          ^
                          |
          +---------------+-------------------+
          |                                   |
    +-----+-----+              +--------------+----------------+
    |   jarga   |              | entity_relationship_manager   |
    | (domains) |              | (graph entities, Neo4j)       |
    +-----+-----+              +-------------------------------+
          ^
          |
          +--- entity_relationship_manager also depends on jarga
               (for workspace membership verification)
```

---

## 16. Open Questions

- [ ] **Q1**: Which Elixir Neo4j driver to use -- `boltx` vs `bolt_sips`? Need to evaluate maturity, maintenance, Neo4j 5.x compatibility.
  - **Blocker?**: Yes -- must decide before implementation
  - **Owner**: Tech lead

- [ ] **Q2**: Should the ERM have its own Ecto Repo or share `Jarga.Repo` for the schema definitions table?
  - **Blocker?**: No -- can start with `Jarga.Repo` and extract later (same pattern as Identity)
  - **Owner**: Tech lead

- [ ] **Q3**: Neo4j hosting strategy -- self-hosted (Docker), Neo4j Aura (managed), or local for dev + managed for prod?
  - **Blocker?**: Yes for deployment, not for development
  - **Owner**: Ops/Infrastructure

---

## Document Metadata

**Document Prepared By**: PRD Agent + User Interview
**Date Created**: 2026-02-13
**Last Updated**: 2026-02-13
**Version**: 1.0
**Status**: Draft
