# PRD: Codebase Knowledge Base MCP Tool

## Summary

- **Problem**: Institutional knowledge about how to build things in the perme8 application is scattered across docs, READMEs, agent prompts, and the heads of contributors. When an LLM agent (or new developer) works on the codebase, there is no structured, queryable way to find relevant patterns, conventions, gotchas, and how-tos. Knowledge gets lost or rediscovered repeatedly.
- **Value**: A graph-structured, workspace-scoped knowledge base lets LLM agents self-serve institutional knowledge while working on the codebase -- reducing errors, improving consistency, and capturing learnings incrementally as agents discover patterns. Think of it as a **graph library of READMEs** that grows over time, isolated per workspace for multi-tenant safety.
- **Users**: Primarily LLM agents (via MCP tools) that author and query knowledge entries while working on the codebase. Secondarily, human developers who benefit from the accumulated knowledge.

---

## User Stories

- As an LLM agent, I want to **search for relevant knowledge** when starting work on a feature, so that I follow established patterns and avoid known pitfalls.
- As an LLM agent, I want to **traverse related knowledge entries** from a starting point, so that I can dive deeper into a topic and discover connected concepts.
- As an LLM agent, I want to **create new knowledge entries** when I discover patterns, conventions, or gotchas while working, so that institutional knowledge accumulates over time.
- As an LLM agent, I want to **update existing knowledge entries** when I find they are outdated or incomplete, so that the knowledge base stays accurate.
- As an LLM agent, I want to **create relationships between knowledge entries**, so that related topics are connected and discoverable through graph traversal.
- As an LLM agent, I want to **get a specific knowledge entry by ID** with its relationships, so that I can read a known piece of knowledge and see what it connects to.

---

## Functional Requirements

### Must Have (P0)

1. **Knowledge Entry CRUD via MCP**
   - Create a knowledge entry with: title, body (markdown), category, tags, code snippets, file path references, external doc links
   - Read a knowledge entry by ID, including its relationships to other entries
   - Update an existing knowledge entry (title, body, tags, etc.)
   - Each entry tracks `last_verified_at` for staleness detection

2. **Knowledge Categories**
   - Six supported categories: `how_to`, `pattern`, `convention`, `architecture_decision`, `gotcha`, `concept`
   - Category is required on every entry
   - Searchable/filterable by category

3. **Keyword & Tag Search**
   - Search entries by keyword (matches against title and body)
   - Search entries by tags (exact match, AND/OR)
   - Filter search results by category
   - Return entries sorted by relevance (title match > body match)

4. **Typed Relationships Between Entries**
   - Create typed relationships between knowledge entries
   - Six relationship types: `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes`
   - Relationships are directional (from → to) with a type label
   - No weighting -- just the relationship type

5. **Graph Traversal**
   - Traverse from a knowledge entry along relationships of a specified type
   - Configurable traversal depth (default: 2, max: 5)
   - Return the subgraph of entries reachable from the starting point
   - Support filtering traversal by relationship type

6. **MCP Tool Interface**
   - `knowledge.search(query, tags, category)` -- keyword/tag search across entries
   - `knowledge.get(id)` -- fetch a specific entry with its relationships
   - `knowledge.traverse(id, relationship_type, depth)` -- walk the graph from an entry
   - `knowledge.create(entry)` -- write a new knowledge entry
   - `knowledge.update(id, entry)` -- update an existing entry
   - `knowledge.relate(from_id, to_id, relationship_type)` -- create relationships between entries
   - All tools are implicitly scoped to the workspace resolved from the API key -- no workspace_id parameter needed

7. **MCP Authentication via Identity API Keys**
   - MCP server authenticates requests using Identity API keys
   - API key resolves to a workspace via Identity -- all operations are scoped to that workspace
   - Agents without a valid API key are rejected
   - No `workspace_id` parameter on tool calls -- workspace context is implicit from auth

8. **Workspace-Scoped Multi-Tenancy**
   - Each workspace has its own isolated knowledge base
   - Knowledge entries are strictly isolated per workspace with no cross-workspace visibility
   - Knowledge base schema (entity types, edge types) is bootstrapped per workspace on first use

### Should Have (P1)

1. **Staleness tracking** -- `last_verified_at` field on entries, with ability to mark entries as verified
2. **Supersedes chain** -- when an entry supersedes another, searches should prefer the newer entry
3. **Entry validation** -- title required, body required, category must be from the allowed set, tags must be non-empty strings

### Nice to Have (P2)

1. **`knowledge.suggest(context)`** -- given a description of what you're working on, return relevant knowledge entries (semantic matching)
2. **Auto-import pipeline** -- seed knowledge from existing `docs/` folder, `AGENTS.md`, and README files
3. **Knowledge entry templates** -- pre-defined structures for each category (e.g., a how-to template with Steps, Prerequisites, etc.)
4. **Batch operations** -- bulk create entries and relationships for initial seeding

---

## User Workflows

### Workflow 1: Agent Queries Knowledge Before Starting Work

1. Agent receives a task (e.g., "add a new API endpoint in jarga_api")
2. Agent calls `knowledge.search(query: "API endpoint", tags: ["jarga_api"])` via MCP
3. System returns matching knowledge entries (e.g., "How to add a new API endpoint in jarga_api")
4. Agent calls `knowledge.get(id)` to read the full entry
5. Agent calls `knowledge.traverse(id, "relates_to", 2)` to discover related entries (e.g., "How authorization works", "API naming conventions")
6. Agent uses the knowledge to correctly implement the feature

### Workflow 2: Agent Captures a Learning

1. Agent discovers a pattern while working (e.g., "all use cases accept dependency injection via opts")
2. Agent calls `knowledge.create(entry)` with title, body, category `pattern`, tags `["use_cases", "dependency_injection", "testing"]`
3. Agent calls `knowledge.search(query: "use cases")` to find related entries
4. Agent calls `knowledge.relate(new_id, existing_id, "example_of")` to connect the new entry to a broader concept
5. Knowledge is now discoverable by future agents

### Workflow 3: Agent Updates Outdated Knowledge

1. Agent finds an entry that references an old pattern
2. Agent creates a new corrected entry via `knowledge.create(entry)`
3. Agent calls `knowledge.relate(new_id, old_id, "supersedes")` to mark the old entry as superseded
4. Agent optionally calls `knowledge.update(old_id, %{body: "SUPERSEDED: See [new entry]"})` to mark the old entry

---

## Data Requirements

### Knowledge Entry

| Field | Type | Required | Constraints | Notes |
|-------|------|----------|-------------|-------|
| id | UUID | Yes | Auto-generated | Primary key |
| title | string | Yes | 1-255 chars | Short, descriptive title |
| body | text (markdown) | Yes | Non-empty | Main content, supports markdown |
| category | string (enum) | Yes | One of 6 categories | `how_to`, `pattern`, `convention`, `architecture_decision`, `gotcha`, `concept` |
| tags | list of strings | No | Each tag non-empty, max 20 tags | Freeform labels for search |
| code_snippets | list of maps | No | Each has `language`, `code`, optional `description` | Embedded code examples |
| file_paths | list of strings | No | Relative paths from project root | References to codebase files |
| external_links | list of maps | No | Each has `url`, optional `title` | Links to external documentation |
| last_verified_at | datetime | No | UTC datetime | When entry was last confirmed accurate |
| created_at | datetime | Yes | Auto-set | |
| updated_at | datetime | Yes | Auto-set | |

### Knowledge Relationship (Edge)

| Field | Type | Required | Constraints | Notes |
|-------|------|----------|-------------|-------|
| id | UUID | Yes | Auto-generated | |
| from_id | UUID | Yes | Must reference existing entry | Source entry |
| to_id | UUID | Yes | Must reference existing entry | Target entry |
| type | string (enum) | Yes | One of 6 relationship types | `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes` |
| created_at | datetime | Yes | Auto-set | |

### Relationships Between Entries

- `relates_to` -- general association between entries
- `depends_on` -- entry A requires understanding of entry B first
- `prerequisite_for` -- entry A must be understood before entry B (inverse of `depends_on`)
- `example_of` -- entry A is a concrete example of the concept in entry B
- `part_of` -- entry A is a sub-topic within the broader topic of entry B
- `supersedes` -- entry A replaces/updates the knowledge in entry B

### Entry Granularity

Entries should be **small and atomic** -- focused on one topic. Broad topics are composed from many small entries connected via `part_of` relationships. For example:

- "Authorization" (concept) ← `part_of` ← "How policy checks work" (how_to)
- "Authorization" (concept) ← `part_of` ← "How roles are structured" (concept)
- "Authorization" (concept) ← `part_of` ← "How to add a permission" (how_to)

---

## Technical Considerations

### Affected Layers

- **Domain**: Knowledge entry struct, relationship type validation, search/traversal policies
- **Application**: Use cases for CRUD, search, traverse; MCP tool handler orchestration
- **Infrastructure**: ERM client (calls EntityRelationshipManager facade), MCP server/transport
- **Interface**: MCP tool endpoint (no HTTP/web interface for v1)

### Architecture: Where Does This Live?

This feature spans two apps:

1. **`entity_relationship_manager`** (ERM) -- Stores knowledge entries as entities and relationships as edges in the graph. The ERM already has full CRUD, traversal, authorization, and a REST API. Knowledge entries are a **use case** of the ERM, not a separate storage system.

2. **New app or module for MCP** -- The MCP server that exposes `knowledge.*` tools to LLM agents. This is the interface layer that translates MCP tool calls into ERM operations.

#### ERM Schema Configuration

Each workspace has its own knowledge entries stored as ERM entities. The knowledge base schema (entity types, edge types) is bootstrapped per workspace on first use or via application setup:

**Entity Type: `KnowledgeEntry`**
- Properties: `title` (string, required), `body` (string, required), `category` (string, required), `tags` (string -- JSON-encoded list), `code_snippets` (string -- JSON-encoded list), `file_paths` (string -- JSON-encoded list), `external_links` (string -- JSON-encoded list), `last_verified_at` (datetime, optional)

**Edge Types**: `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes` (all with no additional properties)

#### MCP Transport

The MCP tool interface needs to be accessible to LLM agents running Claude Code or similar tools. This requires implementing MCP server capability. Options:

- **Option A**: Standalone MCP server process in the umbrella that calls ERM facade directly (in-process, no HTTP overhead)
- **Option B**: MCP server that calls ERM's REST API (out-of-process, more decoupled but HTTP overhead)

**Recommendation**: Option A -- the MCP server should be an Elixir app in the umbrella that directly calls the `EntityRelationshipManager` facade module. This avoids HTTP overhead and leverages existing in-umbrella dependency patterns.

### Integration Points

| System | Integration Type | Purpose |
|--------|------------------|---------|
| EntityRelationshipManager | Read/Write | Stores knowledge entries as entities and relationships as edges |
| MCP protocol | Interface | Exposes `knowledge.*` tools to LLM agents |
| Existing docs (future) | Read | Auto-import seed content from `docs/` folder |

### Key Codebase Facts

- **ERM facade**: `EntityRelationshipManager` module at `apps/entity_relationship_manager/lib/entity_relationship_manager.ex` -- public API for all CRUD, traversal, and bulk operations
- **ERM graph repository behaviour**: `EntityRelationshipManager.Application.Behaviours.GraphRepositoryBehaviour` -- abstraction over graph storage
- **In-memory graph repo**: `EntityRelationshipManager.Infrastructure.Repositories.InMemoryGraphRepository` -- ETS-backed implementation for testing
- **ERM uses dependency injection**: Use cases accept `graph_repo` and `schema_repo` via opts for testability
- **ERM entities are pure structs**: `Entity.t()` has `id`, `workspace_id`, `type`, `properties` (map), `created_at`, `updated_at`, `deleted_at`
- **ERM edges are pure structs**: `Edge.t()` has `id`, `workspace_id`, `type`, `source_id`, `target_id`, `properties` (map), timestamps
- **No MCP exists anywhere** in the codebase -- this is the first MCP implementation

### Performance

- **Search**: < 200ms for keyword/tag search across up to 10,000 entries
- **Traversal**: < 500ms for depth-3 traversal
- **CRUD**: < 200ms for single entry operations
- Knowledge base is expected to start small (hundreds of entries) and grow organically

### Security

- Knowledge base is **multi-tenant via workspaces** -- each workspace has its own isolated knowledge base with no cross-workspace visibility
- Workspace context is resolved from the API key via Identity (the API key maps to a workspace, so all MCP operations are implicitly scoped)
- MCP tools are accessible only to agents with a valid Identity API key mapped to a workspace
- No PII in knowledge entries (they contain institutional/technical knowledge only)

---

## Edge Cases & Error Handling

1. **Duplicate entries**: Agent creates an entry very similar to an existing one → System does NOT auto-deduplicate in v1 (agents should search before creating). Future: suggest similar entries on create.

2. **Self-referencing relationship**: Agent tries to create a relationship from an entry to itself → Return error `{:error, :self_reference}`.

3. **Duplicate relationship**: Agent creates the same relationship twice (same from/to/type) → Return error `{:error, :relationship_exists}` or silently succeed (idempotent). **Decision**: Return the existing relationship (idempotent).

4. **Entry not found on traverse**: Starting entry ID doesn't exist → Return `{:error, :not_found}`.

5. **Invalid category**: Agent provides a category not in the allowed set → Return `{:error, :invalid_category}` with the list of valid categories.

6. **Invalid relationship type**: Agent provides a relationship type not in the allowed set → Return `{:error, :invalid_relationship_type}` with the list of valid types.

7. **Empty search**: No query, tags, or category provided → Return `{:error, :empty_search}` (require at least one search criterion).

8. **Search returns no results**: Valid search with no matches → Return `{:ok, []}` (empty list, not an error).

9. **Superseded entry in search results**: An entry that has been superseded appears in search → Still return it, but include a `superseded_by` field pointing to the newer entry (P1).

10. **Traversal depth exceeds max**: Agent requests depth > 5 → Clamp to max depth of 5, don't error.

---

## Acceptance Criteria

- [ ] **AC1**: An LLM agent can call `knowledge.create` via MCP to create a knowledge entry with title, body, category, and tags -- entry is persisted in the ERM
- [ ] **AC2**: An LLM agent can call `knowledge.search` with a keyword query and get back matching entries sorted by relevance (title match ranked higher)
- [ ] **AC3**: An LLM agent can call `knowledge.search` with tags and/or category to filter results
- [ ] **AC4**: An LLM agent can call `knowledge.get(id)` and receive the full entry with its relationships listed
- [ ] **AC5**: An LLM agent can call `knowledge.relate(from_id, to_id, type)` to create a typed relationship between two entries
- [ ] **AC6**: An LLM agent can call `knowledge.traverse(id, type, depth)` and receive connected entries reachable via relationships of that type up to the given depth
- [ ] **AC7**: An LLM agent can call `knowledge.update(id, attrs)` to update an existing entry's content, tags, or category
- [ ] **AC8**: Invalid inputs (bad category, bad relationship type, missing required fields) return clear error messages
- [ ] **AC9**: Self-referencing relationships are rejected
- [ ] **AC10**: The MCP server starts as part of the umbrella application and is accessible to LLM agents
- [ ] **AC11**: All MCP tool operations are scoped to the workspace resolved from the agent's API key via Identity
- [ ] **AC12**: Agents without a valid API key are rejected with a clear authentication error
- [ ] **AC13**: Knowledge entries from one workspace are not visible or accessible from another workspace

---

## Codebase Context

### Existing Patterns

| Pattern | Location | Relevance |
|---------|----------|-----------|
| ERM facade with use-case delegation | `apps/entity_relationship_manager/lib/entity_relationship_manager.ex` | Knowledge MCP tools will call this facade |
| Pure domain structs (Entity, Edge) | `apps/entity_relationship_manager/lib/.../domain/entities/` | Knowledge entries will be stored as ERM entities |
| Dependency injection via opts | `apps/entity_relationship_manager/lib/.../use_cases/create_entity.ex` | MCP use cases should follow same pattern |
| Graph repository behaviour | `apps/entity_relationship_manager/lib/.../behaviours/graph_repository_behaviour.ex` | In-memory repo available for testing |
| RepoConfig runtime resolution | `apps/entity_relationship_manager/lib/.../application/repo_config.ex` | Pattern for configurable repo implementations |
| Agents app boundary structure | `apps/agents/lib/agents.ex` | Pattern for top-level boundary with layer sub-boundaries |
| Clean Architecture layers | `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md` | Domain > Application > Infrastructure > Interface |
| ERM schema validation | `apps/entity_relationship_manager/lib/.../policies/schema_validation_policy.ex` | Pattern for domain-layer validation policies |

### Affected Contexts

| Context | Impact | Notes |
|---------|--------|-------|
| `EntityRelationshipManager` | Read/Write dependency | Knowledge entries stored as ERM entities/edges |
| New MCP app/module | New bounded context | MCP server + knowledge-specific use cases |
| `Identity` | Auth dependency (required) | API key authentication and workspace resolution |

### Available Infrastructure

- **ERM CRUD + traversal**: Full graph CRUD already exists -- `create_entity`, `create_edge`, `get_neighbors`, `traverse`, `find_paths`, `list_entities`
- **In-memory graph repo**: ETS-backed testing repo with full behaviour implementation
- **Schema validation**: Property validation, type checking, input sanitization
- **Workspace scoping**: All ERM operations are workspace-scoped -- knowledge entries inherit the agent's workspace context resolved from their API key via Identity
- **Boundary enforcement**: Compiler-checked architectural boundaries across all apps

### Umbrella App Structure (existing apps)

```
apps/
  jarga/          -- core domain (workspaces, accounts, projects)
  jarga_web/      -- LiveView web interface
  jarga_api/      -- REST API gateway
  identity/       -- auth, sessions, API keys
  agents/         -- AI agent management (15% complete)
  entity_relationship_manager/  -- graph data layer (CRUD, traversal, schema validation)
  perme8_tools/   -- dev tooling (step linter, boundary scaffolding)
  alkali/         -- static site generator
```

### Existing Docs (potential seed content)

The `docs/` folder contains ~24 markdown files that could eventually be imported as knowledge entries:
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md` -- Clean Architecture patterns
- `docs/prompts/phoenix/PHOENIX_BEST_PRACTICES.md` -- Best practices
- `docs/BOUNDARY_QUICK_REFERENCE.md` -- Boundary enforcement
- `docs/PERMISSIONS.md` -- Authorization system
- `docs/TEST_DATABASE.md` -- Test database setup
- `docs/umbrella_apps.md` -- Umbrella app structure
- Various architectural plans and PRDs

---

## MCP Tool Specifications

### `knowledge.search`

**Purpose**: Find knowledge entries matching a query, tags, or category.

**Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| query | string | No* | - | Keyword search against title and body |
| tags | list of strings | No* | - | Filter by tags (entries must have ALL specified tags) |
| category | string | No | - | Filter by category |
| limit | integer | No | 20 | Max results to return (max: 100) |

*At least one of `query`, `tags`, or `category` must be provided.

**Returns**: List of matching knowledge entries (without full body -- title, category, tags, snippet of body).

### `knowledge.get`

**Purpose**: Fetch a single knowledge entry with full content and relationships.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | UUID | Yes | Knowledge entry ID |

**Returns**: Full knowledge entry with all fields + list of relationships (both inbound and outbound).

### `knowledge.traverse`

**Purpose**: Walk the knowledge graph from a starting entry.

**Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| id | UUID | Yes | - | Starting entry ID |
| relationship_type | string | No | all types | Filter traversal by relationship type |
| depth | integer | No | 2 | Traversal depth (max: 5) |

**Returns**: List of entries reachable from the starting entry, with relationship metadata.

### `knowledge.create`

**Purpose**: Create a new knowledge entry.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| title | string | Yes | Entry title (1-255 chars) |
| body | string | Yes | Markdown content |
| category | string | Yes | One of: `how_to`, `pattern`, `convention`, `architecture_decision`, `gotcha`, `concept` |
| tags | list of strings | No | Freeform tags |
| code_snippets | list of objects | No | Each: `{language, code, description?}` |
| file_paths | list of strings | No | Relative paths to relevant files |
| external_links | list of objects | No | Each: `{url, title?}` |

**Returns**: Created knowledge entry with generated ID.

### `knowledge.update`

**Purpose**: Update an existing knowledge entry.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | UUID | Yes | Entry ID to update |
| title | string | No | Updated title |
| body | string | No | Updated content |
| category | string | No | Updated category |
| tags | list of strings | No | Replaces existing tags |
| code_snippets | list of objects | No | Replaces existing snippets |
| file_paths | list of strings | No | Replaces existing paths |
| external_links | list of objects | No | Replaces existing links |
| last_verified_at | datetime | No | Mark as verified now |

**Returns**: Updated knowledge entry.

### `knowledge.relate`

**Purpose**: Create a relationship between two knowledge entries.

**Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| from_id | UUID | Yes | Source entry ID |
| to_id | UUID | Yes | Target entry ID |
| relationship_type | string | Yes | One of: `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes` |

**Returns**: Created relationship (or existing relationship if duplicate -- idempotent).

---

## Open Questions

- [ ] **Q1**: Which MCP server library/framework to use for Elixir? Need to evaluate available options or implement the MCP protocol directly. The [MCP specification](https://modelcontextprotocol.io/) defines JSON-RPC over stdio or HTTP/SSE -- need to decide transport.
  - **Blocker?**: Yes -- must decide before implementation
  - **Owner**: Tech lead

- [ ] **Q2**: How should the knowledge base workspace be provisioned in the ERM? Should it be auto-created on first MCP tool call, or pre-seeded as part of application setup?
  - **Blocker?**: No -- can start with manual/migration-based setup
  - **Owner**: Architect

- [ ] **Q3**: Should the MCP server live in its own umbrella app (e.g., `apps/knowledge_mcp/`) or as a module within the existing `agents` app?
  - **Blocker?**: No -- can refactor later, but should decide early
  - **Owner**: Architect

- [ ] **Q4**: How to handle ERM schema setup for the knowledge base? The ERM requires a workspace schema to be defined before entities can be created. Should the knowledge base schema be bootstrapped via migration, application startup, or a setup script?
  - **Blocker?**: No -- can hard-code initially
  - **Owner**: Architect

- [x] **Q5**: MCP authentication -- **resolved**: API keys via Identity. API key maps to a workspace, workspace context is implicit on all tool calls. Remaining question: how is the API key passed in the MCP transport (header, init param, etc.)?
  - **Blocker?**: No -- mechanism decided, transport detail for architect
  - **Owner**: Architect

---

## Out of Scope

- **Web UI for knowledge browsing** -- no LiveView or web interface for v1; MCP tools only
- **Semantic/vector search** -- keyword and tag matching only for v1; no embeddings or similarity search
- **Auto-import pipeline** -- no automatic extraction from existing docs; manual authoring only for v1
- **Cross-workspace sharing** -- knowledge entries are strictly isolated per workspace; no sharing mechanism in v1
- **Knowledge entry versioning** -- no version history on entries; `supersedes` relationships handle evolution
- **Access control on entries** -- all entries are readable/writable by any authorized agent
- **`knowledge.suggest(context)` tool** -- deferred to v2
- **Batch/bulk MCP operations** -- single entry operations only for v1
- **Knowledge entry deletion** -- entries can be superseded but not deleted in v1 (soft-delete via ERM exists but not exposed via MCP)

---

## Priority Knowledge Areas (Initial Seeding Targets)

Once the knowledge base is operational, these are the highest-priority areas to populate first:

1. **Architecture & Boundaries** -- Clean Architecture layers, boundary enforcement, how to add new contexts
2. **Development Workflows** -- How to create umbrella apps, run tests, pre-commit checks
3. **Testing Patterns** -- TDD approach, fixture patterns, BDD feature files, test database setup
4. **Auth & Multi-tenancy** -- How authentication works, workspace scoping, role-based access
5. **API Patterns** -- How to add endpoints, API key auth, REST conventions
6. **Agent/LLM Integration** -- How agents work, MCP tools, prompt patterns

---

## Document Metadata

**Document Prepared By**: PRD Agent + User Interview
**Date Created**: 2026-02-17
**Last Updated**: 2026-02-17
**Version**: 1.0
**Status**: Draft
**Related Issues**: #97, #98, #99 (to be updated with corrected understanding)
