# PRD: Knowledge Graph Schema + MCP Tools in Agents App (v2 - Rearchitected)

## Summary

- **Problem**: Institutional knowledge about how to build things in the perme8 application is scattered across docs, READMEs, agent prompts, and the heads of contributors. When an LLM agent (or new developer) works on the codebase, there is no structured, queryable way to find relevant patterns, conventions, gotchas, and how-tos.
- **Value**: A graph-structured, workspace-scoped knowledge base lets LLM agents self-serve institutional knowledge while working on the codebase -- reducing errors, improving consistency, and capturing learnings incrementally.
- **Users**: Primarily LLM agents (via MCP tools) that author and query knowledge entries while working on the codebase. Secondarily, human developers who benefit from the accumulated knowledge.

### Architectural Direction (v2 Rework)

Based on reviewer feedback on PR #100, the architecture has been simplified:

1. **Knowledge graph = ERM schema** -- The knowledge entry entity type and relationship edge types are registered as a schema definition in the ERM. No separate umbrella app is needed. The ERM already handles schema-driven graph entities, so the knowledge graph is just a schema configuration.

2. **MCP = endpoint in the agents app** -- The MCP server, authentication, and tool components live in the `agents` app as a configurable endpoint. The agents app becomes the MCP surface for all tool exposure, with knowledge tools as the first tool set. The tool registration is configuration-driven so future tool sets can be added the same way.

3. **Remove `knowledge_mcp` umbrella app** -- The standalone `apps/knowledge_mcp/` app is deleted entirely. Its valuable pieces (domain validation, MCP tools, auth) are redistributed to the agents app.

---

## User Stories

(Same as v1 -- no changes to user-facing behavior)

- As an LLM agent, I want to **search for relevant knowledge** when starting work on a feature, so that I follow established patterns and avoid known pitfalls.
- As an LLM agent, I want to **traverse related knowledge entries** from a starting point, so that I can dive deeper into a topic and discover connected concepts.
- As an LLM agent, I want to **create new knowledge entries** when I discover patterns, conventions, or gotchas while working, so that institutional knowledge accumulates over time.
- As an LLM agent, I want to **update existing knowledge entries** when I find they are outdated or incomplete, so that the knowledge base stays accurate.
- As an LLM agent, I want to **create relationships between knowledge entries**, so that related topics are connected and discoverable through graph traversal.
- As an LLM agent, I want to **get a specific knowledge entry by ID** with its relationships, so that I can read a known piece of knowledge and see what it connects to.

---

## Functional Requirements

### Must Have (P0)

1. **Knowledge Graph Schema in ERM**
   - Register a `KnowledgeEntry` entity type in the ERM schema with properties: title (string, required), body (string, required), category (string, required), tags (string -- JSON-encoded list), code_snippets (string -- JSON-encoded list), file_paths (string -- JSON-encoded list), external_links (string -- JSON-encoded list), last_verified_at (string, optional)
   - Register 6 edge types: `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes`
   - Schema is bootstrapped per workspace on first MCP tool call (idempotent)
   - All CRUD and traversal operations go through the ERM facade directly

2. **Knowledge Entry Validation** (in agents app domain layer)
   - Category must be one of: `how_to`, `pattern`, `convention`, `architecture_decision`, `gotcha`, `concept`
   - Title required, 1-255 chars
   - Body required, non-empty
   - Tags: each non-empty string, max 20 tags
   - Relationship type must be one of the 6 allowed types
   - Self-referencing relationships rejected

3. **MCP Endpoint in Agents App**
   - Hermes MCP server with StreamableHTTP transport
   - Bearer token authentication via Identity API keys
   - Workspace-scoped multi-tenancy (all operations scoped to workspace from API key)
   - 6 knowledge tools registered as the first tool set:
     - `knowledge.search` -- keyword/tag/category search
     - `knowledge.get` -- fetch entry with relationships
     - `knowledge.traverse` -- walk graph from entry
     - `knowledge.create` -- create new entry
     - `knowledge.update` -- update existing entry
     - `knowledge.relate` -- create relationship between entries

4. **Configuration-Driven Tool Registration**
   - MCP tools are registered via configuration, not hardcoded
   - Future tool sets (e.g., project management, code analysis) can be added by adding configuration, not modifying the MCP server
   - Each tool set is a module that implements a behaviour for tool registration

5. **Search with Relevance Ranking**
   - Keyword search against title and body
   - Tag-based filtering (AND logic)
   - Category filtering
   - Results sorted by relevance (title match > body match)
   - Configurable limit (default 20, max 100)

6. **Graph Traversal**
   - Traverse from entry along relationships of specified type
   - Configurable depth (default 2, max 5, clamped not errored)
   - Filter by relationship type

### Should Have (P1)

1. **Staleness tracking** via `last_verified_at`
2. **Entry validation** with clear error messages
3. **Supersedes chain awareness** in search results

### Nice to Have (P2)

1. `knowledge.suggest(context)` -- semantic matching (deferred)
2. Auto-import from docs folder
3. Batch operations

---

## Architecture

### Where Things Live

```
apps/
  agents/                          # AI agent management + MCP endpoint
    lib/
      agents/
        domain/
          entities/
            agent.ex               # (existing)
            knowledge_entry.ex     # NEW: pure domain struct
            knowledge_relationship.ex  # NEW: pure domain struct
          policies/
            knowledge_validation_policy.ex  # NEW: validation rules
            search_policy.ex       # NEW: search param validation + relevance
        application/
          behaviours/
            erm_gateway_behaviour.ex  # NEW: behaviour for ERM operations
          use_cases/
            # NEW knowledge use cases
            authenticate_mcp_request.ex
            bootstrap_knowledge_schema.ex
            create_knowledge_entry.ex
            update_knowledge_entry.ex
            get_knowledge_entry.ex
            search_knowledge_entries.ex
            traverse_knowledge_graph.ex
            create_knowledge_relationship.ex
        infrastructure/
          gateways/
            erm_gateway.ex         # NEW: thin adapter to ERM facade
          mcp/
            auth_plug.ex           # NEW: Bearer token auth
            router.ex              # NEW: Plug.Router composing auth + Hermes
            server.ex              # NEW: Hermes.Server with tool components
            tools/
              search_tool.ex       # NEW
              get_tool.ex          # NEW
              traverse_tool.ex     # NEW
              create_tool.ex       # NEW
              update_tool.ex       # NEW
              relate_tool.ex       # NEW
  entity_relationship_manager/     # (unchanged - ERM stores the data)
```

### Dependency Flow

```
Agents (MCP endpoint)
  → EntityRelationshipManager (ERM facade -- CRUD, traversal, schema)
  → Identity (API key verification)
```

### Key Decisions

1. **No separate umbrella app** -- MCP lives in agents, knowledge graph is an ERM schema
2. **ERM is the data layer** -- agents app calls ERM facade directly (in-process, no HTTP)
3. **Domain entities in agents** -- KnowledgeEntry/KnowledgeRelationship structs convert to/from ERM entities
4. **Validation in agents** -- Category, tag, relationship type validation is domain logic in agents
5. **Auth via Identity** -- Same pattern as existing ERM auth, but for MCP Bearer tokens
6. **Tool registration via configuration** -- Hermes server reads tool component list from config

---

## Data Requirements

### Knowledge Entry (ERM Entity of type "KnowledgeEntry")

| Field | ERM Property Type | Required | Constraints |
|-------|-------------------|----------|-------------|
| title | string | Yes | 1-255 chars |
| body | string | Yes | Non-empty |
| category | string | Yes | One of 6 categories |
| tags | string (JSON) | No | JSON-encoded list, each tag non-empty, max 20 |
| code_snippets | string (JSON) | No | JSON-encoded list of objects |
| file_paths | string (JSON) | No | JSON-encoded list of strings |
| external_links | string (JSON) | No | JSON-encoded list of objects |
| last_verified_at | string | No | ISO 8601 datetime |

### Knowledge Relationships (ERM Edges)

6 edge types with no additional properties:
- `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes`

---

## MCP Tool Specifications

(Same as v1 -- no changes to tool interface)

### `knowledge.search`
- Parameters: query (string), tags (list), category (string), limit (integer, default 20, max 100)
- At least one of query/tags/category required
- Returns: matching entries with title, category, tags, body snippet

### `knowledge.get`
- Parameters: id (UUID, required)
- Returns: full entry with relationships

### `knowledge.traverse`
- Parameters: id (UUID, required), relationship_type (string), depth (integer, default 2, max 5)
- Returns: reachable entries with relationship metadata

### `knowledge.create`
- Parameters: title (required), body (required), category (required), tags, code_snippets, file_paths, external_links
- Returns: created entry with ID

### `knowledge.update`
- Parameters: id (required), title, body, category, tags, code_snippets, file_paths, external_links, last_verified_at
- Returns: updated entry

### `knowledge.relate`
- Parameters: from_id (required), to_id (required), relationship_type (required)
- Returns: created relationship (idempotent)

---

## Changes Required

### Remove
- Delete entire `apps/knowledge_mcp/` directory
- Remove `knowledge_mcp` from any CI/CD configuration
- Remove `knowledge_mcp` from umbrella mix.exs if referenced

### Add to `apps/agents/`
- `hermes_mcp` dependency in mix.exs
- `entity_relationship_manager` as in_umbrella dependency
- Domain entities: KnowledgeEntry, KnowledgeRelationship
- Domain policies: KnowledgeValidationPolicy, SearchPolicy
- Application behaviours: ErmGatewayBehaviour
- Application use cases: 8 knowledge use cases
- Infrastructure: ErmGateway adapter, MCP server/router/auth/tools
- OTP supervision for Hermes server registry + MCP server
- Boundary configuration updates
- Tests for all new modules

### Modify in `apps/agents/`
- Update boundary deps to include EntityRelationshipManager, Identity
- Update OTP application supervisor to start MCP server
- Add MCP config to config files

---

## Edge Cases & Error Handling

(Same as v1)

1. Self-referencing relationship → `{:error, :self_reference}`
2. Duplicate relationship → return existing (idempotent)
3. Entry not found → `{:error, :not_found}`
4. Invalid category → `{:error, :invalid_category}`
5. Invalid relationship type → `{:error, :invalid_relationship_type}`
6. Empty search → `{:error, :empty_search}`
7. No results → `{:ok, []}`
8. Depth exceeds max → clamp to 5
9. Invalid API key → 401 Unauthorized

---

## Acceptance Criteria

- [x] **AC1**: The `knowledge_mcp` umbrella app is removed
- [x] **AC2**: Knowledge entry entity type and edge types are registered as an ERM schema (bootstrapped per workspace)
- [x] **AC3**: The agents app exposes an MCP endpoint with 6 knowledge tools
- [x] **AC4**: MCP tools authenticate via Identity API keys (Bearer token)
- [x] **AC5**: All knowledge operations are workspace-scoped via the API key
- [x] **AC6**: Tool registration is configuration-driven
- [x] **AC7**: All validation (category, tags, relationships) works correctly
- [x] **AC8**: Search returns results sorted by relevance
- [x] **AC9**: Graph traversal works with configurable depth
- [x] **AC10**: All tests pass (domain, application, infrastructure layers)
- [x] **AC11**: Boundary checks pass (`mix boundary`)
- [x] **AC12**: Pre-commit checks pass (`mix precommit`)

---

## Codebase Context

### Key Files to Reference

| File | Purpose |
|------|---------|
| `apps/agents/lib/agents.ex` | Agents facade + boundary config -- needs MCP additions |
| `apps/agents/lib/agents/otp_app.ex` | OTP supervisor -- needs MCP server children |
| `apps/agents/mix.exs` | Dependencies -- needs hermes_mcp, entity_relationship_manager |
| `apps/entity_relationship_manager/lib/entity_relationship_manager.ex` | ERM facade -- knowledge tools call this |
| `apps/knowledge_mcp/` | Source of code to port (deleted -- ported to agents) |

### Existing Patterns to Follow

- Agents app uses 3-layer boundaries: `Agents.Domain`, `Agents.Application`, `Agents.Infrastructure`
- ERM gateway pattern from knowledge_mcp: thin adapter implementing a behaviour
- Use cases accept DI via opts keyword list
- Mox for test mocking of behaviours
- Pure domain structs with `new/1` and `from_erm_entity/1` converters

---

## Out of Scope

- Web UI for knowledge browsing
- Semantic/vector search
- Auto-import from docs
- Cross-workspace knowledge sharing
- Knowledge entry versioning
- Entry deletion via MCP
- Batch/bulk MCP operations

---

## Document Metadata

**Version**: 2.0 (rearchitected per PR #100 review feedback)
**Date**: 2026-02-17
**Status**: Implemented (branch `refactor/knowledge-mcp-to-agents`, PR #104)
**Related**: PR #100, PR #104, Issues #97, #98, #99
