# Feature: Entity Relationship Manager (ERM)

## Overview

A new umbrella app (`entity_relationship_manager`) providing a schema-driven graph data layer backed by Neo4j (entity/edge storage) and PostgreSQL (schema definitions). Enables workspace-scoped custom entity types, typed relationships, property validation, graph traversal, and bulk operations exposed via a JSON REST API on port 4005.

**PRD Source**: `docs/specs/entity-relationship-manager.md`
**Scope**: P0 (Must Have) requirements only

## UI Strategy

- **LiveView coverage**: 0% — this is a headless API-only app (no UI for MVP)
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `EntityRelationshipManager` (new bounded context, new umbrella app)
- **Dependencies**:
  - `Identity` — API key verification (`Identity.verify_api_key/1`), user lookup (`Identity.get_user/1`)
  - `Jarga.Workspaces` — Membership verification (`Jarga.Workspaces.verify_membership/2`, `Jarga.Workspaces.get_member/2`), permissions policy (`Jarga.Workspaces.Application.Policies.PermissionsPolicy`)
- **Exported schemas**: Domain entities (Entity, Edge, SchemaDefinition) for cross-app integration
- **New context needed?**: Yes — entirely new umbrella app with its own endpoint, router, and Clean Architecture layers

## Architecture Decisions

1. **Neo4j Driver**: Use `boltx` (evaluate maturity early; abstract behind behaviour for swapability)
2. **Ecto Repo**: Use `Jarga.Repo` for PostgreSQL schema definitions (same pattern as JargaApi — no own repo)
3. **Boundary Enforcement**: Compile-time via `boundary` library
4. **App Structure**: Single umbrella app containing both backend logic and web interface (following JargaApi pattern — no separate `_web` app since this is API-only)

## Pre-Implementation: Scaffold Umbrella App

Before Phase 1, scaffold the new umbrella app structure:

- [ ] ⏸ Generate Phoenix app: `cd apps && mix phx.new entity_relationship_manager --no-ecto --no-html --no-assets --no-mailer --no-dashboard --no-live`
- [ ] ⏸ Configure `mix.exs` with dependencies: `{:identity, in_umbrella: true}`, `{:jarga, in_umbrella: true}`, `{:boltx, "~> 0.1"}`, `{:boundary, "~> 0.10", runtime: false}`, `{:jason, "~> 1.2"}`, `{:bandit, "~> 1.5"}`
- [ ] ⏸ Configure boundary settings in `mix.exs` (matching JargaApi pattern)
- [ ] ⏸ Configure endpoint in `config/config.exs` (port 4005), `config/dev.exs`, `config/test.exs`, `config/runtime.exs`
- [ ] ⏸ Set up `EntityRelationshipManager` root module with `use Boundary` and module helper macros (`:router`, `:controller`, `:verified_routes`)
- [ ] ⏸ Set up `EntityRelationshipManager.Application` supervisor starting the endpoint
- [ ] ⏸ Set up `EntityRelationshipManager.Endpoint` (matching JargaApi.Endpoint pattern)
- [ ] ⏸ Create test support modules (`ConnCase`, fixtures)
- [ ] ⏸ Verify `mix compile` succeeds with no warnings
- [ ] ⏸ Verify `mix test` runs (even if empty)

---

## Phase 1: Domain Layer (phoenix-tdd)

Pure business logic — no I/O, no Ecto, no Neo4j. All tests run with `ExUnit.Case, async: true`.

### 1.1 Domain Entity: PropertyDefinition

Value object representing a single property definition within a schema.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/entities/property_definition_test.exs`
  - Tests: `new/1` creates struct from attrs (name, type, required, constraints)
  - Tests: validates property types (:string, :integer, :float, :boolean, :datetime)
  - Tests: default values (required defaults to false, constraints defaults to %{})
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/entities/property_definition.ex`
  - Pure struct with `defstruct [:name, :type, :required, :constraints]`
  - `new/1`, `from_map/1` (for JSONB deserialization)
- [ ] ⏸ **REFACTOR**: Extract type constants, add typespecs

### 1.2 Domain Entity: EntityTypeDefinition

Value object representing a configured entity type within a workspace schema.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/entities/entity_type_definition_test.exs`
  - Tests: `new/1` creates struct with name and list of PropertyDefinitions
  - Tests: `from_map/1` deserializes JSONB map to struct
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/entities/entity_type_definition.ex`
  - Pure struct: `defstruct [:name, :properties]`
  - `new/1`, `from_map/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.3 Domain Entity: EdgeTypeDefinition

Value object representing a configured edge/relationship type.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/entities/edge_type_definition_test.exs`
  - Tests: `new/1` creates struct with name and optional properties
  - Tests: `from_map/1` deserializes JSONB map
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/entities/edge_type_definition.ex`
  - Pure struct: `defstruct [:name, :properties]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.4 Domain Entity: SchemaDefinition

Represents a workspace's full schema configuration (entity types + edge types).

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/entities/schema_definition_test.exs`
  - Tests: `new/1` creates struct with id, workspace_id, entity_types, edge_types, version
  - Tests: `from_schema/1` converts from Ecto infrastructure schema to domain entity
  - Tests: `get_entity_type/2` finds entity type by name
  - Tests: `get_edge_type/2` finds edge type by name
  - Tests: `has_entity_type?/2` and `has_edge_type?/2` return boolean
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/entities/schema_definition.ex`
  - Pure struct with lookup helper functions
- [ ] ⏸ **REFACTOR**: Clean up

### 1.5 Domain Entity: Entity (Graph Node)

Represents a graph entity/node in the domain.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/entities/entity_test.exs`
  - Tests: `new/1` creates struct with id, workspace_id, type, properties, timestamps
  - Tests: `deleted?/1` returns true when deleted_at is set
  - Tests: `from_neo4j_node/1` converts Neo4j result map to domain entity
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/entities/entity.ex`
  - Pure struct: `defstruct [:id, :workspace_id, :type, :properties, :created_at, :updated_at, :deleted_at]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.6 Domain Entity: Edge (Graph Relationship)

Represents a graph edge/relationship in the domain.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/entities/edge_test.exs`
  - Tests: `new/1` creates struct with id, workspace_id, type, source_id, target_id, properties, timestamps
  - Tests: `deleted?/1` returns true when deleted_at is set
  - Tests: `from_neo4j_relationship/1` converts Neo4j result to domain entity
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/entities/edge.ex`
  - Pure struct: `defstruct [:id, :workspace_id, :type, :source_id, :target_id, :properties, :created_at, :updated_at, :deleted_at]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.7 Domain Service: PropertyValidator

Pure validation service for checking property values against type definitions and constraints.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/services/property_validator_test.exs`
  - Tests: validates string type (min_length, max_length, pattern constraints)
  - Tests: validates integer type (min, max constraints)
  - Tests: validates float type (min, max constraints)
  - Tests: validates boolean type
  - Tests: validates datetime type (ISO8601 string parsing)
  - Tests: validates required properties (returns error if missing)
  - Tests: validates optional properties (allows nil/missing)
  - Tests: validates enum constraint (value must be in allowed list)
  - Tests: returns `{:ok, validated_properties}` on success
  - Tests: returns `{:error, errors}` with field-level error details on failure
  - Tests: unknown properties (not in schema) are rejected
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/services/property_validator.ex`
  - `validate_properties/2` takes properties map + list of PropertyDefinitions
  - Returns `{:ok, validated_props}` or `{:error, [%{field: name, message: msg, constraint: type}]}`
- [ ] ⏸ **REFACTOR**: Extract per-type validators into private functions

### 1.8 Domain Policy: SchemaValidationPolicy

Pure business rules for validating schema definitions and validating entities/edges against schemas.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/policies/schema_validation_policy_test.exs`
  - Tests: `validate_schema_structure/1` — valid schema passes
  - Tests: rejects duplicate entity type names
  - Tests: rejects duplicate edge type names
  - Tests: rejects invalid type names (must be alphanumeric + underscore, no empty, reasonable length)
  - Tests: rejects duplicate property names within an entity type
  - Tests: rejects invalid property types
  - Tests: `validate_entity_against_schema/3` — valid entity passes
  - Tests: returns error when entity type not in schema
  - Tests: delegates property validation to PropertyValidator
  - Tests: `validate_edge_against_schema/3` — valid edge passes
  - Tests: returns error when edge type not in schema
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/policies/schema_validation_policy.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.9 Domain Policy: AuthorizationPolicy

Pure business rules for ERM-specific authorization based on workspace roles.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/policies/authorization_policy_test.exs`
  - Tests: owner/admin can manage schemas (read + write)
  - Tests: member can read schemas, create/read/update entities and edges
  - Tests: guest can only read schemas, entities, and edges
  - Tests: `can?/2` with role + action combinations:
    - `:read_schema` — all roles
    - `:write_schema` — owner, admin only
    - `:create_entity` — owner, admin, member
    - `:read_entity` — all roles
    - `:update_entity` — owner, admin, member
    - `:delete_entity` — owner, admin, member
    - `:create_edge` — owner, admin, member
    - `:read_edge` — all roles
    - `:update_edge` — owner, admin, member
    - `:delete_edge` — owner, admin, member
    - `:traverse` — all roles
    - `:bulk_create` — owner, admin, member
    - `:bulk_update` — owner, admin, member
    - `:bulk_delete` — owner, admin, member
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/policies/authorization_policy.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.10 Domain Policy: TraversalPolicy

Pure business rules for traversal safety (depth limits, parameter validation).

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/policies/traversal_policy_test.exs`
  - Tests: `validate_depth/1` — valid depth (1-10) returns :ok
  - Tests: depth > 10 returns `{:error, :depth_too_large}`
  - Tests: depth < 1 returns `{:error, :invalid_depth}`
  - Tests: `validate_direction/1` — "in", "out", "both" are valid
  - Tests: invalid direction returns error
  - Tests: `default_depth/0` returns 1
  - Tests: `max_depth/0` returns 10
  - Tests: `validate_limit/1` — valid range 1-500
  - Tests: `validate_offset/1` — non-negative integer
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/policies/traversal_policy.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.11 Domain Policy: InputSanitizationPolicy

Pure validation for type names and IDs to prevent injection.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/policies/input_sanitization_policy_test.exs`
  - Tests: `validate_type_name/1` — valid alphanumeric + underscore names pass
  - Tests: rejects names with special characters, spaces, SQL/Cypher-unsafe patterns
  - Tests: rejects empty names, names > 100 chars
  - Tests: `validate_uuid/1` — valid UUID format passes
  - Tests: rejects invalid UUID formats
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/policies/input_sanitization_policy.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1 Validation

- [ ] ⏸ All domain entity tests pass (milliseconds, no I/O)
- [ ] ⏸ All domain policy tests pass (milliseconds, no I/O)
- [ ] ⏸ All domain service tests pass (milliseconds, no I/O)
- [ ] ⏸ No boundary violations (`mix compile --warnings-as-errors`)

---

## Phase 2: Application Layer — Behaviours (phoenix-tdd)

Define behaviour contracts for infrastructure dependencies (repositories) that use cases will depend on via dependency injection.

### 2.1 Behaviour: SchemaRepositoryBehaviour

- [ ] ⏸ **RED**: Write test (compile-time check — implementing module must match callbacks)
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/behaviours/schema_repository_behaviour.ex`
  - Callbacks:
    - `get_schema(workspace_id) :: {:ok, SchemaDefinition.t()} | {:error, :not_found}`
    - `upsert_schema(workspace_id, attrs) :: {:ok, SchemaDefinition.t()} | {:error, term()}`
- [ ] ⏸ **REFACTOR**: Ensure typespecs are precise

### 2.2 Behaviour: GraphRepositoryBehaviour

- [ ] ⏸ **RED**: Write test (compile-time check)
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/behaviours/graph_repository_behaviour.ex`
  - Callbacks:
    - `create_entity(workspace_id, type, properties) :: {:ok, Entity.t()} | {:error, term()}`
    - `get_entity(workspace_id, entity_id) :: {:ok, Entity.t()} | {:error, :not_found}`
    - `list_entities(workspace_id, filters) :: {:ok, [Entity.t()]}`
    - `update_entity(workspace_id, entity_id, properties) :: {:ok, Entity.t()} | {:error, term()}`
    - `soft_delete_entity(workspace_id, entity_id) :: {:ok, Entity.t(), deleted_edge_count :: integer()} | {:error, term()}`
    - `create_edge(workspace_id, type, source_id, target_id, properties) :: {:ok, Edge.t()} | {:error, term()}`
    - `get_edge(workspace_id, edge_id) :: {:ok, Edge.t()} | {:error, :not_found}`
    - `list_edges(workspace_id, filters) :: {:ok, [Edge.t()]}`
    - `update_edge(workspace_id, edge_id, properties) :: {:ok, Edge.t()} | {:error, term()}`
    - `soft_delete_edge(workspace_id, edge_id) :: {:ok, Edge.t()} | {:error, term()}`
    - `get_neighbors(workspace_id, entity_id, opts) :: {:ok, [Entity.t()]}`
    - `find_paths(workspace_id, source_id, target_id, opts) :: {:ok, [path]}`
    - `traverse(workspace_id, start_id, opts) :: {:ok, [Entity.t()]}`
    - `bulk_create_entities(workspace_id, entities) :: {:ok, [Entity.t()]} | {:error, term()}`
    - `bulk_create_edges(workspace_id, edges) :: {:ok, [Edge.t()]} | {:error, term()}`
    - `bulk_update_entities(workspace_id, updates) :: {:ok, [Entity.t()]} | {:error, term()}`
    - `bulk_soft_delete_entities(workspace_id, entity_ids) :: {:ok, integer()} | {:error, term()}`
    - `health_check() :: :ok | {:error, term()}`
- [ ] ⏸ **REFACTOR**: Group callbacks logically, add docs

---

## Phase 3: Application Layer — Use Cases (phoenix-tdd)

Orchestration layer. Tests use `Mox` for repository mocks. Test case: `ExUnit.Case, async: true` with Mox setup.

### 3.1 Mox Setup

- [ ] ⏸ Create `apps/entity_relationship_manager/test/support/mocks.ex` defining:
  - `EntityRelationshipManager.Mocks.SchemaRepositoryMock` for `SchemaRepositoryBehaviour`
  - `EntityRelationshipManager.Mocks.GraphRepositoryMock` for `GraphRepositoryBehaviour`
- [ ] ⏸ Register mocks in `test/test_helper.exs`

### 3.2 Use Case: GetSchema

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/get_schema_test.exs`
  - Tests: returns schema when it exists for workspace
  - Tests: returns `{:error, :not_found}` when no schema exists
  - Mocks: SchemaRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/get_schema.ex`
  - Accepts `workspace_id` and `opts` (for DI)
  - Delegates to schema_repository
- [ ] ⏸ **REFACTOR**: Clean up

### 3.3 Use Case: UpsertSchema

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/upsert_schema_test.exs`
  - Tests: creates schema when none exists (validates structure first)
  - Tests: updates schema with optimistic locking (version check)
  - Tests: returns validation errors for invalid schema structure
  - Tests: rejects concurrent modification (stale version)
  - Mocks: SchemaRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/upsert_schema.ex`
  - Validates schema via SchemaValidationPolicy
  - Persists via schema_repository
- [ ] ⏸ **REFACTOR**: Clean up

### 3.4 Use Case: CreateEntity

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/create_entity_test.exs`
  - Tests: creates entity when type exists in schema and properties valid
  - Tests: returns error when no schema configured for workspace
  - Tests: returns error when entity type not in schema
  - Tests: returns error when properties fail validation
  - Tests: sanitizes type name
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/create_entity.ex`
  - Fetches schema → validates entity type exists → validates properties → creates in graph
- [ ] ⏸ **REFACTOR**: Extract validation pipeline

### 3.5 Use Case: GetEntity

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/get_entity_test.exs`
  - Tests: returns entity by ID within workspace
  - Tests: returns `{:error, :not_found}` for non-existent entity
  - Tests: validates UUID format
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/get_entity.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.6 Use Case: ListEntities

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/list_entities_test.exs`
  - Tests: lists entities filtered by type
  - Tests: respects include_deleted flag
  - Tests: respects limit/offset pagination
  - Tests: validates filter parameters
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/list_entities.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.7 Use Case: UpdateEntity

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/update_entity_test.exs`
  - Tests: updates entity properties (validated against schema)
  - Tests: returns error for invalid properties
  - Tests: returns error when entity not found
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/update_entity.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.8 Use Case: DeleteEntity

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/delete_entity_test.exs`
  - Tests: soft-deletes entity and cascading edges
  - Tests: returns entity with deleted_at set + count of deleted edges
  - Tests: returns error when entity not found
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/delete_entity.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.9 Use Case: CreateEdge

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/create_edge_test.exs`
  - Tests: creates edge between two existing entities with valid type
  - Tests: validates edge type exists in schema
  - Tests: validates edge properties against schema
  - Tests: returns error when source or target entity not found
  - Tests: sanitizes type name
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/create_edge.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.10 Use Case: GetEdge

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/get_edge_test.exs`
  - Tests: returns edge by ID within workspace
  - Tests: returns error when not found
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/get_edge.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.11 Use Case: ListEdges

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/list_edges_test.exs`
  - Tests: lists edges filtered by type, entity_id, direction
  - Tests: respects include_deleted, limit, offset
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/list_edges.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.12 Use Case: UpdateEdge

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/update_edge_test.exs`
  - Tests: updates edge properties (validated against schema)
  - Tests: returns error for invalid properties
  - Tests: returns error when edge not found
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/update_edge.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.13 Use Case: DeleteEdge

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/delete_edge_test.exs`
  - Tests: soft-deletes edge
  - Tests: returns error when not found
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/delete_edge.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.14 Use Case: GetNeighbors

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/get_neighbors_test.exs`
  - Tests: returns direct neighbors (1-degree) of an entity
  - Tests: filters by direction ("in", "out", "both")
  - Tests: filters by entity type and/or edge type
  - Tests: validates parameters via TraversalPolicy
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/get_neighbors.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.15 Use Case: FindPaths

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/find_paths_test.exs`
  - Tests: finds paths between two entities
  - Tests: respects depth limit
  - Tests: filters by entity/edge type
  - Tests: validates parameters via TraversalPolicy
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/find_paths.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.16 Use Case: Traverse

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/traverse_test.exs`
  - Tests: N-degree traversal from starting entity
  - Tests: configurable depth (default 1, max 10)
  - Tests: filters by entity/edge type and direction
  - Tests: validates parameters via TraversalPolicy
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/traverse.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.17 Use Case: BulkCreateEntities

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/bulk_create_entities_test.exs`
  - Tests: creates batch of entities (all validated against schema)
  - Tests: atomic mode — all-or-nothing on validation failure
  - Tests: partial mode — creates valid items, returns errors for invalid
  - Tests: respects batch size limit (max 1000)
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/bulk_create_entities.ex`
- [ ] ⏸ **REFACTOR**: Extract common bulk validation logic

### 3.18 Use Case: BulkUpdateEntities

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/bulk_update_entities_test.exs`
  - Tests: updates batch of entities
  - Tests: atomic and partial modes
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/bulk_update_entities.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.19 Use Case: BulkDeleteEntities

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/bulk_delete_entities_test.exs`
  - Tests: soft-deletes batch of entities with cascading edge deletion
  - Tests: atomic and partial modes
  - Mocks: GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/bulk_delete_entities.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.20 Use Case: BulkCreateEdges

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/bulk_create_edges_test.exs`
  - Tests: creates batch of edges (all validated against schema)
  - Tests: atomic and partial modes
  - Mocks: SchemaRepositoryMock, GraphRepositoryMock
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/bulk_create_edges.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3 Validation

- [ ] ⏸ All use case tests pass (with mocks, no I/O)
- [ ] ⏸ No boundary violations (`mix compile --warnings-as-errors`)
- [ ] ⏸ All Phase 1 + 3 tests still pass

---

## Phase 4: Infrastructure Layer — PostgreSQL (phoenix-tdd)

Ecto schema and repository for schema definitions stored in PostgreSQL.

### 4.1 Migration: entity_schemas table

- [ ] ⏸ Create migration `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_entity_schemas.exs`
  - Table `entity_schemas`:
    - `id` :binary_id, primary key
    - `workspace_id` :binary_id, not null, references workspaces(id) on_delete: :restrict
    - `entity_types` :map (JSONB), not null, default: []
    - `edge_types` :map (JSONB), not null, default: []
    - `version` :integer, not null, default: 1
    - `timestamps(type: :utc_datetime)`
  - Unique index on `workspace_id` (one schema per workspace)

### 4.2 Infrastructure Schema: SchemaDefinitionSchema

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/infrastructure/schemas/schema_definition_schema_test.exs`
  - Tests: valid changeset with all required fields
  - Tests: changeset rejects missing workspace_id
  - Tests: changeset rejects missing entity_types and edge_types
  - Tests: `to_entity/1` converts to domain SchemaDefinition
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/infrastructure/schemas/schema_definition_schema.ex`
  - `use Ecto.Schema`, schema "entity_schemas"
  - Fields: workspace_id, entity_types (map), edge_types (map), version
  - Changesets: `create_changeset/2`, `update_changeset/2` (with optimistic lock on version)
  - `to_entity/1` for converting to domain entity
- [ ] ⏸ **REFACTOR**: Clean up

### 4.3 Infrastructure Repository: SchemaRepository

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/infrastructure/repositories/schema_repository_test.exs`
  - Tests: `get_schema/1` returns domain entity when schema exists
  - Tests: `get_schema/1` returns `{:error, :not_found}` when no schema
  - Tests: `upsert_schema/2` creates new schema for workspace
  - Tests: `upsert_schema/2` updates existing schema (increments version)
  - Tests: `upsert_schema/2` rejects stale version (optimistic locking)
  - (These tests hit the database — use `Jarga.DataCase` or equivalent)
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/infrastructure/repositories/schema_repository.ex`
  - Implements `SchemaRepositoryBehaviour`
  - Uses `Jarga.Repo` for database access
  - Injectable repo via opts
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 4 Validation

- [ ] ⏸ Migration runs successfully (`mix ecto.migrate`)
- [ ] ⏸ All schema tests pass
- [ ] ⏸ All repository tests pass (with database)
- [ ] ⏸ All Phase 1 + 3 tests still pass

---

## Phase 5: Infrastructure Layer — Neo4j (phoenix-tdd)

Neo4j adapter and graph repository implementation.

### 5.1 Infrastructure Adapter: Neo4jAdapter

Thin wrapper around the `boltx` driver for executing Cypher queries.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/infrastructure/adapters/neo4j_adapter_test.exs`
  - Tests: `execute/2` sends parameterized Cypher query and returns results
  - Tests: `execute/2` returns `{:error, :unavailable}` when connection fails
  - Tests: always uses parameterized queries (no string interpolation of user values)
  - (Integration tests — require Neo4j running; tag with `@tag :neo4j`)
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/infrastructure/adapters/neo4j_adapter.ex`
  - Wraps `Boltx` connection pool
  - `execute(cypher, params)` — parameterized query execution
  - `health_check()` — verify connectivity
  - Telemetry events for query timing
- [ ] ⏸ **REFACTOR**: Add error handling, circuit breaker considerations

### 5.2 Infrastructure: Neo4j Connection Pool

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/infrastructure/adapters/neo4j_connection_pool_test.exs`
  - Tests: pool starts with configured size
  - Tests: health check returns :ok when connected
  - Tests: health check returns error when disconnected
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/infrastructure/adapters/neo4j_connection_pool.ex`
  - GenServer or supervised Boltx connection pool
  - Configurable pool size via application config
- [ ] ⏸ **REFACTOR**: Clean up

### 5.3 Infrastructure Repository: GraphRepository

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/infrastructure/repositories/graph_repository_test.exs`
  - Tests: CRUD for entities (create, get, list, update, soft-delete)
  - Tests: CRUD for edges (create, get, list, update, soft-delete)
  - Tests: workspace scoping — entities from other workspaces not returned
  - Tests: soft-delete entity cascades to edges
  - Tests: get_neighbors returns correct neighbors by direction
  - Tests: find_paths returns paths between connected entities
  - Tests: traverse returns N-degree connections with depth limit
  - Tests: bulk_create_entities creates multiple entities
  - Tests: bulk_create_edges creates multiple edges
  - Tests: bulk_update_entities updates multiple entities
  - Tests: bulk_soft_delete_entities deletes multiple entities
  - Tests: health_check returns :ok
  - Tests: include_deleted flag includes soft-deleted items
  - Tests: limit/offset pagination works
  - (Integration tests — require Neo4j; tag with `@tag :neo4j`)
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/infrastructure/repositories/graph_repository.ex`
  - Implements `GraphRepositoryBehaviour`
  - All Cypher queries parameterized (never interpolate user input)
  - All queries include `_workspace_id` filter for tenant isolation
  - Generates UUIDs for `_id` fields
  - Sets `_created_at`, `_updated_at`, `_deleted_at` timestamps
  - Uses `:Entity` common label + type-specific label on nodes
  - Injectable adapter via opts
- [ ] ⏸ **REFACTOR**: Extract Cypher query builders into helper module

### Phase 5 Validation

- [ ] ⏸ All Neo4j integration tests pass (with running Neo4j)
- [ ] ⏸ All previous phase tests still pass
- [ ] ⏸ No boundary violations

---

## Phase 6: Public Facade (phoenix-tdd)

The `EntityRelationshipManager` context module — thin facade delegating to use cases.

### 6.1 Context Facade: EntityRelationshipManager

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager_test.exs`
  - Tests: facade delegates to use cases (verify function signatures exist and pass-through works)
  - Tests: public API functions:
    - `get_schema/1`
    - `upsert_schema/2`
    - `create_entity/3`, `get_entity/2`, `list_entities/2`, `update_entity/3`, `delete_entity/2`
    - `create_edge/5`, `get_edge/2`, `list_edges/2`, `update_edge/3`, `delete_edge/2`
    - `get_neighbors/3`, `find_paths/4`, `traverse/3`
    - `bulk_create_entities/3`, `bulk_update_entities/3`, `bulk_delete_entities/3`
    - `bulk_create_edges/3`
  - Mocks: use Mox for repository dependencies
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager.ex`
  - `use Boundary` with:
    - `deps: [Identity, Jarga.Workspaces, Jarga.Repo]`
    - `exports: [Domain.Entities.Entity, Domain.Entities.Edge, Domain.Entities.SchemaDefinition]`
  - Thin delegation to use cases
- [ ] ⏸ **REFACTOR**: Ensure < 200 lines, add complete @doc annotations

### Phase 6 Validation

- [ ] ⏸ Facade tests pass
- [ ] ⏸ No boundary violations
- [ ] ⏸ Full domain + application + infrastructure test suite passes

---

## Phase 7: Interface Layer — Plugs & Auth (phoenix-tdd)

Authentication and authorization plugs for the API endpoint.

### 7.1 Plug: WorkspaceAuthPlug

Composite plug that handles: Bearer token auth → user lookup → workspace membership → role assignment.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/plugs/workspace_auth_plug_test.exs`
  - Tests: valid Bearer token + valid workspace → assigns :current_user, :api_key, :workspace, :member_role
  - Tests: missing Authorization header → 401 with JSON error
  - Tests: invalid/revoked API key → 401 with JSON error
  - Tests: valid API key but user not a workspace member → 404 (not 403, to avoid leaking existence)
  - Tests: workspace_id not a valid UUID → 400 Bad Request
  - Tests: halts conn on auth failure
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/plugs/workspace_auth_plug.ex`
  - Extracts Bearer token from Authorization header
  - Calls `Identity.verify_api_key/1` to verify token
  - Calls `Identity.get_user/1` to get user
  - Calls `Jarga.Workspaces.get_member/2` to get workspace membership + role
  - Assigns `:current_user`, `:api_key`, `:workspace`, `:member` (with role) to conn
- [ ] ⏸ **REFACTOR**: Extract helper functions

### 7.2 Plug: AuthorizationPlug (or inline in controller)

Authorization check that verifies the member role has permission for the requested action.

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/plugs/authorize_plug_test.exs`
  - Tests: authorized role proceeds (conn not halted)
  - Tests: unauthorized role returns 403 Forbidden with JSON error
  - Tests: configurable action per route
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/plugs/authorize_plug.ex`
  - Takes `:action` option
  - Reads `:member` assign from conn to get role
  - Delegates to `AuthorizationPolicy.can?/2`
  - Returns 403 if unauthorized
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 7 Validation

- [ ] ⏸ All plug tests pass
- [ ] ⏸ No boundary violations

---

## Phase 8: Interface Layer — Controllers & Views (phoenix-tdd)

JSON API controllers and views.

### 8.1 View: ErrorJSON

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/views/error_json_test.exs`
  - Tests: renders 401, 403, 404, 422, 500, 503 error formats
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/views/error_json.ex`
  - Standard error JSON responses matching PRD format
- [ ] ⏸ **REFACTOR**: Clean up

### 8.2 View: SchemaJSON

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/views/schema_json_test.exs`
  - Tests: renders schema with entity_types, edge_types, version
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/views/schema_json.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 8.3 View: EntityJSON

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/views/entity_json_test.exs`
  - Tests: renders single entity with all fields
  - Tests: renders list of entities
  - Tests: renders bulk create/update response
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/views/entity_json.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 8.4 View: EdgeJSON

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/views/edge_json_test.exs`
  - Tests: renders single edge with all fields
  - Tests: renders list of edges
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/views/edge_json.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 8.5 Controller: HealthController

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/controllers/health_controller_test.exs`
  - Tests: `GET /health` returns 200 with `{"status": "ok"}` when Neo4j is available
  - Tests: `GET /health` returns 503 with `{"status": "unavailable"}` when Neo4j is down
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/controllers/health_controller.ex`
  - Calls graph_repository.health_check()
- [ ] ⏸ **REFACTOR**: Clean up

### 8.6 Controller: SchemaController

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/controllers/schema_controller_test.exs`
  - Tests: `GET /api/v1/workspaces/:workspace_id/schema` returns schema (all roles)
  - Tests: `GET` returns 404 when no schema exists
  - Tests: `PUT /api/v1/workspaces/:workspace_id/schema` creates/updates schema (admin/owner)
  - Tests: `PUT` returns 403 for member/guest
  - Tests: `PUT` returns 422 for invalid schema structure
  - Tests: `PUT` returns 409 for version conflict (optimistic locking)
  - Tests: unauthenticated request returns 401
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/controllers/schema_controller.ex`
  - `show/2` — GET schema
  - `update/2` — PUT schema (upsert)
  - Delegates to `EntityRelationshipManager` facade
  - Uses `AuthorizePlug` for `:write_schema` on PUT
- [ ] ⏸ **REFACTOR**: Clean up

### 8.7 Controller: EntityController

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/controllers/entity_controller_test.exs`
  - Tests: `POST /api/v1/workspaces/:workspace_id/entities` creates entity (201)
  - Tests: `POST` returns 422 for validation failures
  - Tests: `POST` returns 403 for guest role
  - Tests: `GET /api/v1/workspaces/:workspace_id/entities` lists entities
  - Tests: `GET` with `?type=Person` filters by type
  - Tests: `GET` with `?include_deleted=true` includes soft-deleted
  - Tests: `GET` with `?limit=10&offset=0` paginates
  - Tests: `GET /api/v1/workspaces/:workspace_id/entities/:id` returns single entity
  - Tests: `GET` returns 404 for non-existent entity
  - Tests: `PUT /api/v1/workspaces/:workspace_id/entities/:id` updates entity
  - Tests: `DELETE /api/v1/workspaces/:workspace_id/entities/:id` soft-deletes entity
  - Tests: `DELETE` returns cascaded edge count in response
  - Tests: `POST /api/v1/workspaces/:workspace_id/entities/bulk` bulk creates
  - Tests: `PUT /api/v1/workspaces/:workspace_id/entities/bulk` bulk updates
  - Tests: `DELETE /api/v1/workspaces/:workspace_id/entities/bulk` bulk soft-deletes
  - Tests: bulk with `?mode=atomic` rejects entire batch on failure
  - Tests: bulk with `?mode=partial` creates valid items, returns errors
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/controllers/entity_controller.ex`
  - Actions: `create`, `index`, `show`, `update`, `delete`, `bulk_create`, `bulk_update`, `bulk_delete`
  - Delegates to `EntityRelationshipManager` facade
  - Maps query params to filter structs
- [ ] ⏸ **REFACTOR**: Extract param parsing into helper module

### 8.8 Controller: EdgeController

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/controllers/edge_controller_test.exs`
  - Tests: `POST /api/v1/workspaces/:workspace_id/edges` creates edge (201)
  - Tests: `POST` returns 422 for validation failures
  - Tests: `POST` returns 403 for guest role
  - Tests: `GET /api/v1/workspaces/:workspace_id/edges` lists edges
  - Tests: `GET` with `?type=EMPLOYS` filters by type
  - Tests: `GET /api/v1/workspaces/:workspace_id/edges/:id` returns single edge
  - Tests: `PUT /api/v1/workspaces/:workspace_id/edges/:id` updates edge properties
  - Tests: `DELETE /api/v1/workspaces/:workspace_id/edges/:id` soft-deletes edge
  - Tests: `POST /api/v1/workspaces/:workspace_id/edges/bulk` bulk creates edges
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/controllers/edge_controller.ex`
  - Actions: `create`, `index`, `show`, `update`, `delete`, `bulk_create`
- [ ] ⏸ **REFACTOR**: Clean up

### 8.9 Controller: TraversalController

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/controllers/traversal_controller_test.exs`
  - Tests: `GET /api/v1/workspaces/:workspace_id/entities/:id/neighbors` returns neighbors
  - Tests: `?direction=in` filters inbound only
  - Tests: `?direction=out` filters outbound only
  - Tests: `?type=Person` filters by entity type
  - Tests: `GET /api/v1/workspaces/:workspace_id/entities/:id/paths/:target_id` returns paths
  - Tests: `?depth=3` limits path length
  - Tests: `GET /api/v1/workspaces/:workspace_id/traverse` returns N-degree connections
  - Tests: `?start_id=...&depth=2` configurable traversal
  - Tests: depth > 10 returns 422
  - Tests: 403 for unauthorized role (N/A — all roles can traverse, so test guest can traverse)
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/controllers/traversal_controller.ex`
  - Actions: `neighbors`, `paths`, `traverse`
- [ ] ⏸ **REFACTOR**: Clean up

### 8.10 Router

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/router_test.exs`
  - Tests: all routes are properly defined and accessible
  - Tests: health endpoint is unauthenticated
  - Tests: API routes require authentication
- [ ] ⏸ **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/router.ex`
  ```elixir
  pipeline :api_base do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug EntityRelationshipManager.Plugs.WorkspaceAuthPlug
  end

  # Health check (unauthenticated)
  scope "/", EntityRelationshipManager do
    pipe_through [:api_base]
    get "/health", HealthController, :show
  end

  # Workspace-scoped API routes
  scope "/api/v1/workspaces/:workspace_id", EntityRelationshipManager do
    pipe_through [:api_base, :api_authenticated]

    # Schema
    get "/schema", SchemaController, :show
    put "/schema", SchemaController, :update

    # Entities
    post "/entities", EntityController, :create
    get "/entities", EntityController, :index
    post "/entities/bulk", EntityController, :bulk_create
    put "/entities/bulk", EntityController, :bulk_update
    delete "/entities/bulk", EntityController, :bulk_delete
    get "/entities/:id", EntityController, :show
    put "/entities/:id", EntityController, :update
    delete "/entities/:id", EntityController, :delete

    # Edges
    post "/edges", EdgeController, :create
    get "/edges", EdgeController, :index
    post "/edges/bulk", EdgeController, :bulk_create
    get "/edges/:id", EdgeController, :show
    put "/edges/:id", EdgeController, :update
    delete "/edges/:id", EdgeController, :delete

    # Traversal
    get "/entities/:id/neighbors", TraversalController, :neighbors
    get "/entities/:id/paths/:target_id", TraversalController, :paths
    get "/traverse", TraversalController, :traverse
  end
  ```
- [ ] ⏸ **REFACTOR**: Ensure route order is correct (bulk before :id to avoid conflicts)

### Phase 8 Validation

- [ ] ⏸ All controller tests pass
- [ ] ⏸ All view tests pass
- [ ] ⏸ Router test passes
- [ ] ⏸ No boundary violations
- [ ] ⏸ All previous tests still pass

---

## Phase 9: Integration & Final Validation

### 9.1 Boundary Configuration

- [ ] ⏸ Verify all `use Boundary` declarations are correct:
  - `EntityRelationshipManager` — top-level, deps: [Identity, Jarga.Workspaces, Jarga.Repo], exports domain entities
  - `EntityRelationshipManager.Application` (OTP app) — deps: [EntityRelationshipManager]
  - Internal modules are NOT exported
- [ ] ⏸ `mix compile --warnings-as-errors` passes with zero boundary warnings

### 9.2 End-to-End Smoke Test

- [ ] ⏸ **RED**: Write integration test `apps/entity_relationship_manager/test/entity_relationship_manager/integration/full_lifecycle_test.exs`
  - Tests full workflow:
    1. Authenticate (setup API key + workspace membership)
    2. PUT schema with entity types (Person, Company) and edge types (EMPLOYS)
    3. POST entity (Person with valid properties)
    4. POST entity (Company)
    5. POST edge (Company EMPLOYS Person)
    6. GET neighbors of Company → includes Person
    7. GET paths from Person to Company
    8. PUT update Person properties
    9. DELETE Person (soft) → verify cascading edge soft-delete
    10. GET entities with include_deleted=true → Person still visible
  - (Integration test — requires both PostgreSQL and Neo4j; tag with `@tag :integration`)
- [ ] ⏸ **GREEN**: All components work together
- [ ] ⏸ **REFACTOR**: Clean up

### 9.3 Multi-Tenancy Isolation Test

- [ ] ⏸ **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/integration/tenant_isolation_test.exs`
  - Tests: entities created in workspace A are NOT visible in workspace B
  - Tests: edges created in workspace A are NOT visible in workspace B
  - Tests: traversal in workspace A does NOT cross into workspace B
  - Tests: API returns 404 (not 403) when accessing cross-workspace entities
- [ ] ⏸ **GREEN**: Verify isolation works
- [ ] ⏸ **REFACTOR**: Clean up

### 9.4 Pre-Commit Checkpoint

- [ ] ⏸ `mix format` — all files formatted
- [ ] ⏸ `mix credo` — no warnings
- [ ] ⏸ `mix compile --warnings-as-errors` — clean compile
- [ ] ⏸ `mix boundary` — no violations
- [ ] ⏸ `mix test` — full suite passes (unit + integration)
- [ ] ⏸ `mix precommit` — all checks pass

---

## Testing Strategy

### Test Distribution

| Layer | Test Count (est.) | Speed | I/O |
|-------|------------------|-------|-----|
| Domain entities | ~20 | <1ms each | None |
| Domain policies | ~40 | <1ms each | None |
| Domain services | ~15 | <1ms each | None |
| Application use cases | ~60 | <5ms each (mocked) | None (Mox) |
| Infrastructure schemas | ~5 | <50ms each | PostgreSQL |
| Infrastructure repos (PG) | ~8 | <50ms each | PostgreSQL |
| Infrastructure repos (Neo4j) | ~25 | <100ms each | Neo4j |
| Infrastructure adapters | ~5 | <100ms each | Neo4j |
| Plugs | ~10 | <10ms each | None (Mox) |
| Controllers | ~40 | <100ms each | PostgreSQL + Neo4j |
| Views | ~10 | <1ms each | None |
| Integration | ~10 | <500ms each | PostgreSQL + Neo4j |
| **Total** | **~248** | | |

### Test Tagging Strategy

- Default tests: domain, policies, services, use cases (run always)
- `@tag :database` — PostgreSQL-dependent tests
- `@tag :neo4j` — Neo4j-dependent tests (can be skipped in CI without Neo4j)
- `@tag :integration` — full stack integration tests

### Mocking Strategy

- **Neo4j**: Mocked via `GraphRepositoryBehaviour` + Mox in use case tests
- **PostgreSQL**: Mocked via `SchemaRepositoryBehaviour` + Mox in use case tests; real DB in repository tests
- **Identity**: Real module calls in controller tests (via test fixtures); could mock for unit plug tests
- **Jarga.Workspaces**: Real module calls in controller tests; mock in plug unit tests

---

## File Structure Summary

```
apps/entity_relationship_manager/
├── lib/
│   ├── entity_relationship_manager.ex                          # Public facade + Boundary
│   ├── entity_relationship_manager/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── property_definition.ex
│   │   │   │   ├── entity_type_definition.ex
│   │   │   │   ├── edge_type_definition.ex
│   │   │   │   ├── schema_definition.ex
│   │   │   │   ├── entity.ex
│   │   │   │   └── edge.ex
│   │   │   ├── policies/
│   │   │   │   ├── schema_validation_policy.ex
│   │   │   │   ├── authorization_policy.ex
│   │   │   │   ├── traversal_policy.ex
│   │   │   │   └── input_sanitization_policy.ex
│   │   │   └── services/
│   │   │       └── property_validator.ex
│   │   ├── application/
│   │   │   ├── behaviours/
│   │   │   │   ├── schema_repository_behaviour.ex
│   │   │   │   └── graph_repository_behaviour.ex
│   │   │   └── use_cases/
│   │   │       ├── get_schema.ex
│   │   │       ├── upsert_schema.ex
│   │   │       ├── create_entity.ex
│   │   │       ├── get_entity.ex
│   │   │       ├── list_entities.ex
│   │   │       ├── update_entity.ex
│   │   │       ├── delete_entity.ex
│   │   │       ├── create_edge.ex
│   │   │       ├── get_edge.ex
│   │   │       ├── list_edges.ex
│   │   │       ├── update_edge.ex
│   │   │       ├── delete_edge.ex
│   │   │       ├── get_neighbors.ex
│   │   │       ├── find_paths.ex
│   │   │       ├── traverse.ex
│   │   │       ├── bulk_create_entities.ex
│   │   │       ├── bulk_update_entities.ex
│   │   │       ├── bulk_delete_entities.ex
│   │   │       └── bulk_create_edges.ex
│   │   ├── infrastructure/
│   │   │   ├── schemas/
│   │   │   │   └── schema_definition_schema.ex
│   │   │   ├── repositories/
│   │   │   │   ├── schema_repository.ex
│   │   │   │   └── graph_repository.ex
│   │   │   └── adapters/
│   │   │       ├── neo4j_adapter.ex
│   │   │       └── neo4j_connection_pool.ex
│   │   ├── plugs/
│   │   │   ├── workspace_auth_plug.ex
│   │   │   └── authorize_plug.ex
│   │   ├── controllers/
│   │   │   ├── health_controller.ex
│   │   │   ├── schema_controller.ex
│   │   │   ├── entity_controller.ex
│   │   │   ├── edge_controller.ex
│   │   │   └── traversal_controller.ex
│   │   ├── views/
│   │   │   ├── error_json.ex
│   │   │   ├── schema_json.ex
│   │   │   ├── entity_json.ex
│   │   │   └── edge_json.ex
│   │   ├── router.ex
│   │   ├── endpoint.ex
│   │   └── telemetry.ex
│   └── entity_relationship_manager/application.ex              # OTP Application
├── test/
│   ├── entity_relationship_manager/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── property_definition_test.exs
│   │   │   │   ├── entity_type_definition_test.exs
│   │   │   │   ├── edge_type_definition_test.exs
│   │   │   │   ├── schema_definition_test.exs
│   │   │   │   ├── entity_test.exs
│   │   │   │   └── edge_test.exs
│   │   │   ├── policies/
│   │   │   │   ├── schema_validation_policy_test.exs
│   │   │   │   ├── authorization_policy_test.exs
│   │   │   │   ├── traversal_policy_test.exs
│   │   │   │   └── input_sanitization_policy_test.exs
│   │   │   └── services/
│   │   │       └── property_validator_test.exs
│   │   ├── application/
│   │   │   └── use_cases/
│   │   │       ├── get_schema_test.exs
│   │   │       ├── upsert_schema_test.exs
│   │   │       ├── create_entity_test.exs
│   │   │       ├── get_entity_test.exs
│   │   │       ├── list_entities_test.exs
│   │   │       ├── update_entity_test.exs
│   │   │       ├── delete_entity_test.exs
│   │   │       ├── create_edge_test.exs
│   │   │       ├── get_edge_test.exs
│   │   │       ├── list_edges_test.exs
│   │   │       ├── update_edge_test.exs
│   │   │       ├── delete_edge_test.exs
│   │   │       ├── get_neighbors_test.exs
│   │   │       ├── find_paths_test.exs
│   │   │       ├── traverse_test.exs
│   │   │       ├── bulk_create_entities_test.exs
│   │   │       ├── bulk_update_entities_test.exs
│   │   │       ├── bulk_delete_entities_test.exs
│   │   │       └── bulk_create_edges_test.exs
│   │   ├── infrastructure/
│   │   │   ├── schemas/
│   │   │   │   └── schema_definition_schema_test.exs
│   │   │   ├── repositories/
│   │   │   │   ├── schema_repository_test.exs
│   │   │   │   └── graph_repository_test.exs
│   │   │   └── adapters/
│   │   │       ├── neo4j_adapter_test.exs
│   │   │       └── neo4j_connection_pool_test.exs
│   │   ├── plugs/
│   │   │   ├── workspace_auth_plug_test.exs
│   │   │   └── authorize_plug_test.exs
│   │   ├── controllers/
│   │   │   ├── health_controller_test.exs
│   │   │   ├── schema_controller_test.exs
│   │   │   ├── entity_controller_test.exs
│   │   │   ├── edge_controller_test.exs
│   │   │   └── traversal_controller_test.exs
│   │   ├── views/
│   │   │   ├── error_json_test.exs
│   │   │   ├── schema_json_test.exs
│   │   │   ├── entity_json_test.exs
│   │   │   └── edge_json_test.exs
│   │   └── integration/
│   │       ├── full_lifecycle_test.exs
│   │       └── tenant_isolation_test.exs
│   ├── entity_relationship_manager_test.exs
│   ├── support/
│   │   ├── conn_case.ex
│   │   ├── data_case.ex
│   │   ├── fixtures.ex
│   │   ├── mocks.ex
│   │   └── neo4j_sandbox.ex
│   └── test_helper.exs
├── mix.exs
└── README.md
```

---

## Dependency Graph

```
                    +-----------+
                    |  Identity |
                    |  (auth)   |
                    +-----+-----+
                          ^
                          |
          +---------------+-------------------+
          |                                   |
    +-----+-----+              +--------------+--------------------+
    |   Jarga   |              | EntityRelationshipManager          |
    | Workspaces|<-------------|  (graph entities, Neo4j + PG)     |
    +-----------+              +------------------------------------+
```

## Configuration Additions

### `config/config.exs`
```elixir
# Entity Relationship Manager endpoint configuration
config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: EntityRelationshipManager.Views.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub
```

### `config/dev.exs`
```elixir
config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4005],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "erm_dev_secret_key_base_at_least_64_bytes_long_for_security",
  watchers: []

# Neo4j connection for development
config :entity_relationship_manager, :neo4j,
  url: "bolt://localhost:7687",
  basic_auth: [username: "neo4j", password: "password"],
  pool_size: 10
```

### `config/test.exs`
```elixir
config :entity_relationship_manager, EntityRelationshipManager.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4105],
  secret_key_base: "erm_test_secret_key_base_at_least_64_bytes_long_for_security",
  server: false

# Neo4j test configuration
config :entity_relationship_manager, :neo4j,
  url: "bolt://localhost:7688",
  basic_auth: [username: "neo4j", password: "test"],
  pool_size: 5
```

## Open Questions (to resolve before/during implementation)

1. **Neo4j driver choice**: Evaluate `boltx` vs `bolt_sips` for Neo4j 5.x compatibility. The behaviour abstraction allows swapping later.
2. **Neo4j test isolation**: Need a strategy for cleaning Neo4j between tests (truncate workspace-scoped data, or use a test database). Consider implementing `neo4j_sandbox.ex` module.
3. **Neo4j in CI**: Decide whether CI runs Neo4j (Docker service) or skips Neo4j-dependent tests. Tag-based exclusion supports both approaches.
4. **Shared Repo vs Own Repo**: Plan uses `Jarga.Repo` following JargaApi pattern. If isolation is needed later, extract to `EntityRelationshipManager.Repo`.

---

## Document Metadata

**Created by**: Architect Agent
**PRD Source**: `docs/specs/entity-relationship-manager.md`
**Date Created**: 2026-02-14
**Last Updated**: 2026-02-14
**Version**: 1.0
**Status**: ⏸ Not Started
