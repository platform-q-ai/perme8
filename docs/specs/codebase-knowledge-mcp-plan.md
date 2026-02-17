# Feature: Codebase Knowledge Base MCP Server

## Overview

A graph-structured, workspace-scoped knowledge base exposed via MCP (Model Context Protocol) tools. LLM agents authenticate via Identity API keys, then create, search, traverse, and maintain institutional knowledge entries stored as ERM graph entities. The MCP server is a new umbrella app (`knowledge_mcp`) using the Hermes MCP library for protocol/transport, calling the `EntityRelationshipManager` facade in-process for all graph operations.

## Architectural Decisions

### Q1 Resolution: MCP Server Library
**Decision**: Use [Hermes MCP](https://hex.pm/packages/hermes_mcp) (`hermes_mcp`), a production-quality Elixir MCP framework providing server capabilities, tool registration, JSON-RPC over HTTP/SSE transport, and a component-based architecture.

### Q3 Resolution: Umbrella App
**Decision**: New umbrella app `apps/knowledge_mcp/`. This is a distinct bounded context (MCP protocol + knowledge-specific logic) separate from both ERM (generic graph layer) and Agents (AI agent management). The app is a plain Elixir app with `--sup` (no Ecto, no Phoenix -- it calls ERM in-process).

### Q4 Resolution: Schema Bootstrapping
**Decision**: Lazy bootstrapping on first MCP tool call per workspace. A `BootstrapKnowledgeSchema` use case checks if the workspace already has the knowledge schema registered in ERM and creates it if not. This is idempotent and requires no migrations.

### Q5 Resolution: API Key Transport
**Decision**: API key passed as a Bearer token in the HTTP Authorization header. The Hermes HTTP transport receives it; a custom plug extracts and verifies it via `Identity.verify_api_key/1`, resolving the workspace_id from the API key's `workspace_access` list.

## UI Strategy
- **LiveView coverage**: 0% (no web interface in v1 -- MCP tools only)
- **TypeScript needed**: None

## Affected Boundaries
- **Primary context**: `KnowledgeMcp` (new umbrella app)
- **Dependencies**:
  - `EntityRelationshipManager` -- graph CRUD, traversal, schema management (called via public facade)
  - `Identity` -- API key verification (`Identity.verify_api_key/1`)
- **Exported schemas**: None (the MCP app is a leaf node -- nothing depends on it)
- **New context needed?**: Yes -- `knowledge_mcp` is a new bounded context

## New App Structure

```
apps/knowledge_mcp/
  lib/
    knowledge_mcp.ex                          # Public facade + Boundary definition
    knowledge_mcp/
      domain/
        entities/
          knowledge_entry.ex                  # Pure domain struct for knowledge entries
          knowledge_relationship.ex           # Pure domain struct for relationships
        policies/
          knowledge_validation_policy.ex      # Category, tag, relationship type validation
          search_policy.ex                    # Search parameter validation, relevance scoring
      application/
        behaviours/
          erm_gateway_behaviour.ex            # Behaviour for ERM operations (testable)
        use_cases/
          bootstrap_knowledge_schema.ex       # Idempotent ERM schema setup per workspace
          create_knowledge_entry.ex           # Create entry via ERM
          update_knowledge_entry.ex           # Update entry via ERM
          get_knowledge_entry.ex              # Get entry + relationships via ERM
          search_knowledge_entries.ex         # Keyword/tag search with relevance ranking
          traverse_knowledge_graph.ex         # Graph traversal from entry
          create_knowledge_relationship.ex    # Create typed relationship via ERM
          authenticate_request.ex             # API key verification + workspace resolution
      infrastructure/
        erm_gateway.ex                        # Implementation calling EntityRelationshipManager facade
        mcp/
          server.ex                           # Hermes.Server definition with tool registration
          tools/
            search_tool.ex                    # knowledge.search component
            get_tool.ex                       # knowledge.get component
            traverse_tool.ex                  # knowledge.traverse component
            create_tool.ex                    # knowledge.create component
            update_tool.ex                    # knowledge.update component
            relate_tool.ex                    # knowledge.relate component
          auth_plug.ex                        # Plug for API key extraction/verification
      otp_app.ex                              # Application supervisor
  test/
    knowledge_mcp/
      domain/
        entities/
          knowledge_entry_test.exs
          knowledge_relationship_test.exs
        policies/
          knowledge_validation_policy_test.exs
          search_policy_test.exs
      application/
        use_cases/
          bootstrap_knowledge_schema_test.exs
          create_knowledge_entry_test.exs
          update_knowledge_entry_test.exs
          get_knowledge_entry_test.exs
          search_knowledge_entries_test.exs
          traverse_knowledge_graph_test.exs
          create_knowledge_relationship_test.exs
          authenticate_request_test.exs
      infrastructure/
        erm_gateway_test.exs
        mcp/
          server_test.exs
          tools/
            search_tool_test.exs
            get_tool_test.exs
            traverse_tool_test.exs
            create_tool_test.exs
            update_tool_test.exs
            relate_tool_test.exs
          auth_plug_test.exs
    support/
      mocks.ex
      fixtures.ex
    test_helper.exs
  mix.exs
```

---

## Phase 1: Domain + Application (phoenix-tdd) ✓

### Step 1.1: Scaffold the Umbrella App

- [x] Create new umbrella app: `cd apps && mix new knowledge_mcp --sup`
- [x] Configure `mix.exs` with dependencies: `hermes_mcp`, `jason`, `boundary`, `mox` (test), in-umbrella deps (`identity`, `entity_relationship_manager`)
- [x] Configure `boundary: [externals_mode: :relaxed, ignore: [~r/\.Test\./]]` in mix.exs
- [x] Create `test/support/mocks.ex` with Mox mock definitions for `ErmGatewayBehaviour`
- [x] Create `test/support/fixtures.ex` with test fixture helpers
- [x] Create `test/test_helper.exs` with ExUnit setup
- [x] Verify `mix compile` succeeds with no warnings

### Step 1.2: KnowledgeEntry Domain Entity

Domain entity representing a knowledge entry. Pure struct wrapping ERM Entity properties with typed fields.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/domain/entities/knowledge_entry_test.exs`
  - Tests:
    - `new/1` creates a struct from valid attrs (title, body, category, tags, etc.)
    - `new/1` sets defaults for optional fields (tags: [], code_snippets: [], file_paths: [], external_links: [])
    - `from_erm_entity/1` converts an ERM `Entity.t()` with properties into a `KnowledgeEntry`
    - `to_erm_properties/1` converts a `KnowledgeEntry` to ERM-compatible properties map (JSON-encoding lists)
    - `snippet/1` returns first 200 chars of body for search result previews
    - All fields are correctly typed and accessible
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/domain/entities/knowledge_entry.ex`
  - Pure struct: `id`, `workspace_id`, `title`, `body`, `category`, `tags`, `code_snippets`, `file_paths`, `external_links`, `last_verified_at`, `created_at`, `updated_at`
  - Functions: `new/1`, `from_erm_entity/1`, `to_erm_properties/1`, `snippet/1`
- [x] **REFACTOR**: Clean up, add typespecs and moduledoc

### Step 1.3: KnowledgeRelationship Domain Entity

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/domain/entities/knowledge_relationship_test.exs`
  - Tests:
    - `new/1` creates a struct from valid attrs (id, from_id, to_id, type, created_at)
    - `from_erm_edge/1` converts an ERM `Edge.t()` into a `KnowledgeRelationship`
    - All 6 relationship types are representable
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/domain/entities/knowledge_relationship.ex`
  - Pure struct: `id`, `from_id`, `to_id`, `type`, `created_at`
  - Functions: `new/1`, `from_erm_edge/1`
- [x] **REFACTOR**: Clean up, add typespecs

### Step 1.4: KnowledgeValidationPolicy

Pure business rules for validating knowledge entry attributes and relationship types.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/domain/policies/knowledge_validation_policy_test.exs`
  - Tests:
    - `valid_category?/1` returns true for each of the 6 categories: `how_to`, `pattern`, `convention`, `architecture_decision`, `gotcha`, `concept`
    - `valid_category?/1` returns false for invalid categories
    - `valid_relationship_type?/1` returns true for each of the 6 types: `relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes`
    - `valid_relationship_type?/1` returns false for invalid types
    - `validate_entry_attrs/1` returns `:ok` for valid attrs (title + body + category present)
    - `validate_entry_attrs/1` returns `{:error, :title_required}` when title missing/empty
    - `validate_entry_attrs/1` returns `{:error, :body_required}` when body missing/empty
    - `validate_entry_attrs/1` returns `{:error, :invalid_category}` for bad category
    - `validate_entry_attrs/1` returns `{:error, :title_too_long}` for title > 255 chars
    - `validate_update_attrs/1` returns `:ok` for partial updates (no required fields when updating)
    - `validate_update_attrs/1` returns `{:error, :invalid_category}` if category present but invalid
    - `validate_tags/1` returns `:ok` for valid tag list (non-empty strings, max 20)
    - `validate_tags/1` returns `{:error, :too_many_tags}` for > 20 tags
    - `validate_tags/1` returns `{:error, :invalid_tag}` for empty string tags
    - `validate_self_reference/2` returns `:ok` when from_id != to_id
    - `validate_self_reference/2` returns `{:error, :self_reference}` when from_id == to_id
    - `categories/0` returns the list of all valid categories
    - `relationship_types/0` returns the list of all valid relationship types
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/domain/policies/knowledge_validation_policy.ex`
- [x] **REFACTOR**: Extract constants, ensure all rules are pure

### Step 1.5: SearchPolicy

Pure business rules for search parameter validation and relevance ranking.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/domain/policies/search_policy_test.exs`
  - Tests:
    - `validate_search_params/1` returns `:ok` when at least one of query/tags/category is present
    - `validate_search_params/1` returns `{:error, :empty_search}` when none provided
    - `validate_search_params/1` clamps limit to 1..100 range (default 20)
    - `validate_search_params/1` returns `{:error, :invalid_category}` for bad category filter
    - `score_relevance/2` returns higher score for title match than body match
    - `score_relevance/2` returns 0 for no match
    - `score_relevance/2` is case-insensitive
    - `matches_tags?/2` returns true when entry has ALL specified tags (AND logic)
    - `matches_tags?/2` returns false when entry is missing any specified tag
    - `matches_category?/2` returns true when entry matches category filter
    - `matches_category?/2` returns true when no category filter (nil)
    - `clamp_depth/1` clamps traversal depth to 1..5 range (default 2)
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/domain/policies/search_policy.ex`
- [x] **REFACTOR**: Clean up relevance scoring algorithm

### Step 1.6: ErmGatewayBehaviour

Behaviour defining the contract for ERM operations. Enables mocking in use case tests.

- [x] **RED**: Write test (no test needed -- this is a behaviour definition, tested through implementations)
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/behaviours/erm_gateway_behaviour.ex`
  - Callbacks:
    - `get_schema(workspace_id) :: {:ok, SchemaDefinition.t()} | {:error, term()}`
    - `upsert_schema(workspace_id, attrs) :: {:ok, SchemaDefinition.t()} | {:error, term()}`
    - `create_entity(workspace_id, attrs) :: {:ok, Entity.t()} | {:error, term()}`
    - `get_entity(workspace_id, entity_id) :: {:ok, Entity.t()} | {:error, :not_found}`
    - `update_entity(workspace_id, entity_id, attrs) :: {:ok, Entity.t()} | {:error, term()}`
    - `list_entities(workspace_id, filters) :: {:ok, [Entity.t()]}`
    - `create_edge(workspace_id, attrs) :: {:ok, Edge.t()} | {:error, term()}`
    - `list_edges(workspace_id, filters) :: {:ok, [Edge.t()]}`
    - `get_neighbors(workspace_id, entity_id, opts) :: {:ok, [Entity.t()]}`
    - `traverse(workspace_id, start_id, opts) :: {:ok, [Entity.t()]}`
- [x] **REFACTOR**: Ensure types match ERM facade signatures
- [x] Add `ErmGatewayMock` to `test/support/mocks.ex` via `Mox.defmock`

### Step 1.7: AuthenticateRequest Use Case

Verifies API key and resolves workspace context.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/authenticate_request_test.exs`
  - Tests:
    - Returns `{:ok, %{workspace_id: id, user_id: id}}` for valid API key with workspace access
    - Returns `{:error, :unauthorized}` for invalid API key (Identity returns `{:error, :invalid}`)
    - Returns `{:error, :unauthorized}` for inactive API key (Identity returns `{:error, :inactive}`)
    - Returns `{:error, :no_workspace_access}` when API key has empty `workspace_access` list
    - Uses first workspace_id from the API key's `workspace_access` list
    - Accepts `identity_module` via opts for dependency injection
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/authenticate_request.ex`
  - Calls `Identity.verify_api_key(token)` (injected via opts)
  - Extracts workspace_id from `api_key.workspace_access`
  - Returns `{:ok, %{workspace_id: workspace_id, user_id: api_key.user_id}}`
- [x] **REFACTOR**: Clean up error handling

### Step 1.8: BootstrapKnowledgeSchema Use Case

Idempotent ERM schema setup per workspace.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/bootstrap_knowledge_schema_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - When schema already exists with KnowledgeEntry type, returns `{:ok, :already_bootstrapped}`
    - When schema exists but missing KnowledgeEntry type, upserts schema adding the knowledge types
    - When no schema exists (`{:error, :not_found}`), creates full schema with entity type + edge types
    - Schema includes entity type `KnowledgeEntry` with properties: title (string, required), body (string, required), category (string, required), tags (string), code_snippets (string), file_paths (string), external_links (string), last_verified_at (string)
    - Schema includes all 6 edge types: relates_to, depends_on, prerequisite_for, example_of, part_of, supersedes
    - Is idempotent -- calling twice does not error
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/bootstrap_knowledge_schema.ex`
- [x] **REFACTOR**: Extract schema definition constants

### Step 1.9: CreateKnowledgeEntry Use Case

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/create_knowledge_entry_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - Creates entry with valid attrs, returns `{:ok, knowledge_entry}`
    - Calls `BootstrapKnowledgeSchema` first (ensures schema exists)
    - Creates ERM entity with type "KnowledgeEntry" and JSON-encoded list properties
    - Returns `{:error, :title_required}` for missing title
    - Returns `{:error, :body_required}` for missing body
    - Returns `{:error, :invalid_category}` for bad category
    - Returns `{:error, :too_many_tags}` for > 20 tags
    - Converts ERM Entity response back to KnowledgeEntry domain entity
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/create_knowledge_entry.ex`
- [x] **REFACTOR**: Clean up

### Step 1.10: UpdateKnowledgeEntry Use Case

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/update_knowledge_entry_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - Updates entry with valid partial attrs, returns `{:ok, knowledge_entry}`
    - Returns `{:error, :not_found}` when entry doesn't exist
    - Returns `{:error, :invalid_category}` if category provided but invalid
    - Merges update properties with existing entity properties
    - Handles `last_verified_at` update (marks as verified)
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/update_knowledge_entry.ex`
- [x] **REFACTOR**: Clean up

### Step 1.11: GetKnowledgeEntry Use Case

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/get_knowledge_entry_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - Returns `{:ok, %{entry: knowledge_entry, relationships: [...]}}` for existing entry
    - Fetches entry via `get_entity` + relationships via `list_edges` (inbound + outbound)
    - Returns `{:error, :not_found}` for non-existent entry
    - Relationships include both inbound and outbound edges
    - Converts all ERM entities/edges to domain types
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/get_knowledge_entry.ex`
- [x] **REFACTOR**: Clean up

### Step 1.12: SearchKnowledgeEntries Use Case

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/search_knowledge_entries_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - Searches by keyword query against title and body, returns sorted results
    - Filters by tags (AND logic -- entry must have all specified tags)
    - Filters by category
    - Combines query + tags + category filters
    - Returns `{:error, :empty_search}` when no search criteria provided
    - Limits results to the specified limit (default 20, max 100)
    - Title matches rank higher than body matches
    - Returns entries as KnowledgeEntry domain objects with snippet (not full body)
    - Returns `{:ok, []}` for valid search with no matches
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/search_knowledge_entries.ex`
  - Lists all KnowledgeEntry entities from ERM
  - Applies SearchPolicy for filtering and scoring
  - Sorts by relevance score descending
  - Returns truncated entries (snippets instead of full body)
- [x] **REFACTOR**: Optimize search (consider future pagination via ERM filters)

### Step 1.13: TraverseKnowledgeGraph Use Case

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/traverse_knowledge_graph_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - Traverses from starting entry, returns reachable entries with relationship metadata
    - Filters by relationship type when specified
    - Uses default depth of 2 when not specified
    - Clamps depth to max 5 (no error, just clamp)
    - Returns `{:error, :not_found}` for non-existent starting entry
    - Returns `{:error, :invalid_relationship_type}` for bad relationship type
    - Converts ERM results to KnowledgeEntry domain objects
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/traverse_knowledge_graph.ex`
  - Validates relationship_type via KnowledgeValidationPolicy
  - Clamps depth via SearchPolicy
  - Calls ERM traverse (or get_neighbors iteratively) with edge type filter
- [x] **REFACTOR**: Clean up

### Step 1.14: CreateKnowledgeRelationship Use Case

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/create_knowledge_relationship_test.exs`
  - Mocks: `ErmGatewayMock`
  - Tests:
    - Creates relationship between two entries, returns `{:ok, knowledge_relationship}`
    - Returns `{:error, :self_reference}` when from_id == to_id
    - Returns `{:error, :invalid_relationship_type}` for bad type
    - Returns `{:error, :not_found}` when source entry doesn't exist
    - Returns `{:error, :not_found}` when target entry doesn't exist
    - Idempotent: returns existing relationship if duplicate (same from/to/type)
    - Calls BootstrapKnowledgeSchema first
    - Creates ERM edge with correct source_id, target_id, type
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application/use_cases/create_knowledge_relationship.ex`
- [x] **REFACTOR**: Clean up

### Step 1.15: KnowledgeMcp Facade

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp_test.exs`
  - Tests: Facade delegates correctly to use cases (smoke test for each public function)
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp.ex`
  - `use Boundary` with deps on `EntityRelationshipManager`, `Identity`
  - Public functions: `authenticate/1`, `search/2`, `get/2`, `traverse/2`, `create/2`, `update/3`, `relate/2`
  - Each delegates to the corresponding use case
- [x] **REFACTOR**: Add @doc and @spec

### Phase 1 Validation
- [x] All domain tests pass (milliseconds, no I/O): `mix test apps/knowledge_mcp/test/knowledge_mcp/domain/`
- [x] All application tests pass (with mocks): `mix test apps/knowledge_mcp/test/knowledge_mcp/application/`
- [x] No boundary violations: `mix compile --warnings-as-errors` in knowledge_mcp app
- [x] Total Phase 1 tests pass: `mix test` in knowledge_mcp app

---

## Phase 2: Infrastructure + Interface (phoenix-tdd) ✓

### Step 2.1: ErmGateway Implementation

Thin adapter calling the `EntityRelationshipManager` facade in-process.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/erm_gateway_test.exs`
  - Note: This is an integration test that requires ERM mocks or ERM's InMemoryGraphRepository
  - Tests:
    - `get_schema/1` delegates to `EntityRelationshipManager.get_schema/2`
    - `upsert_schema/2` delegates to `EntityRelationshipManager.upsert_schema/3`
    - `create_entity/2` delegates to `EntityRelationshipManager.create_entity/3`
    - `get_entity/2` delegates to `EntityRelationshipManager.get_entity/3`
    - `update_entity/3` delegates to `EntityRelationshipManager.update_entity/4`
    - `list_entities/2` delegates to `EntityRelationshipManager.list_entities/3`
    - `create_edge/2` delegates to `EntityRelationshipManager.create_edge/3`
    - `list_edges/2` delegates to `EntityRelationshipManager.list_edges/3`
    - `get_neighbors/3` delegates to `EntityRelationshipManager.get_neighbors/3`
    - `traverse/3` delegates to `EntityRelationshipManager.traverse/2`
    - All calls include workspace_id in the correct position
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/erm_gateway.ex`
  - Implements `ErmGatewayBehaviour`
  - Each function is a thin delegation to the `EntityRelationshipManager` facade
  - Translates parameter shapes as needed (e.g., keyword opts for traverse)
- [x] **REFACTOR**: Ensure error types are properly mapped

### Step 2.2: AuthPlug

Plug that extracts API key from Authorization header and authenticates.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/auth_plug_test.exs`
  - Tests:
    - Extracts Bearer token from Authorization header
    - Calls `AuthenticateRequest` use case with the token
    - On success: stores `workspace_id` and `user_id` in conn assigns
    - On missing header: returns 401 with JSON error
    - On invalid token: returns 401 with JSON error
    - On inactive token: returns 401 with JSON error
    - Handles "Bearer " prefix correctly (case-insensitive)
    - Ignores non-Bearer auth schemes
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/auth_plug.ex`
  - `Plug.Conn` based -- extracts bearer token, calls `AuthenticateRequest`, assigns or halts
- [x] **REFACTOR**: Clean up error responses

### Step 2.3: MCP Server Definition

Hermes MCP server with tool registration.

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/server_test.exs`
  - Tests:
    - Server module compiles and defines all required callbacks
    - `init/2` registers all 6 tools: `knowledge.search`, `knowledge.get`, `knowledge.traverse`, `knowledge.create`, `knowledge.update`, `knowledge.relate`
    - Each tool has correct input_schema definition matching PRD parameters
    - Server name and version are set correctly
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/server.ex`
  - `use Hermes.Server, name: "knowledge-mcp", version: "1.0.0", capabilities: [:tools]`
  - Register 6 tool components in `init/2`
  - Each tool has descriptive name, description, and JSON Schema input
- [x] **REFACTOR**: Extract shared tool schemas

### Step 2.4: knowledge.search Tool Component

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/search_tool_test.exs`
  - Tests:
    - Calls `SearchKnowledgeEntries` use case with parsed params
    - Returns formatted text content with search results
    - Handles `{:ok, []}` (no results) gracefully
    - Handles `{:error, :empty_search}` with user-friendly error
    - Passes workspace_id from frame assigns to use case
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/tools/search_tool.ex`
  - `use Hermes.Server.Component, type: :tool`
  - Schema: query (string, optional), tags (array, optional), category (string, optional), limit (integer, optional)
  - Delegates to `SearchKnowledgeEntries` use case
  - Formats response as text content
- [x] **REFACTOR**: Clean up response formatting

### Step 2.5: knowledge.get Tool Component

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/get_tool_test.exs`
  - Tests:
    - Calls `GetKnowledgeEntry` use case with entry ID
    - Returns full entry content with relationships
    - Handles `{:error, :not_found}` with user-friendly error
    - Formats relationships as readable list
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/tools/get_tool.ex`
  - Schema: id (string, required)
  - Delegates to `GetKnowledgeEntry` use case
- [x] **REFACTOR**: Clean up

### Step 2.6: knowledge.traverse Tool Component

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/traverse_tool_test.exs`
  - Tests:
    - Calls `TraverseKnowledgeGraph` use case with entry ID, relationship type, depth
    - Returns formatted traversal results
    - Handles optional relationship_type (defaults to all)
    - Handles optional depth (defaults to 2)
    - Handles `{:error, :not_found}` gracefully
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/tools/traverse_tool.ex`
  - Schema: id (string, required), relationship_type (string, optional), depth (integer, optional)
  - Delegates to `TraverseKnowledgeGraph` use case
- [x] **REFACTOR**: Clean up

### Step 2.7: knowledge.create Tool Component

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/create_tool_test.exs`
  - Tests:
    - Calls `CreateKnowledgeEntry` use case with all params
    - Returns created entry with ID
    - Handles validation errors with descriptive messages
    - Passes workspace_id from frame assigns
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/tools/create_tool.ex`
  - Schema: title (string, required), body (string, required), category (string, required), tags (array, optional), code_snippets (array, optional), file_paths (array, optional), external_links (array, optional)
  - Delegates to `CreateKnowledgeEntry` use case
- [x] **REFACTOR**: Clean up

### Step 2.8: knowledge.update Tool Component

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/update_tool_test.exs`
  - Tests:
    - Calls `UpdateKnowledgeEntry` use case with entry ID and partial attrs
    - Returns updated entry
    - Handles `{:error, :not_found}` gracefully
    - Handles validation errors
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/tools/update_tool.ex`
  - Schema: id (string, required), title (string, optional), body (string, optional), category (string, optional), tags (array, optional), code_snippets (array, optional), file_paths (array, optional), external_links (array, optional), last_verified_at (string, optional)
  - Delegates to `UpdateKnowledgeEntry` use case
- [x] **REFACTOR**: Clean up

### Step 2.9: knowledge.relate Tool Component

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/relate_tool_test.exs`
  - Tests:
    - Calls `CreateKnowledgeRelationship` use case with from_id, to_id, type
    - Returns created relationship
    - Handles `{:error, :self_reference}` with descriptive error
    - Handles `{:error, :invalid_relationship_type}` with list of valid types
    - Handles `{:error, :not_found}` gracefully
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/infrastructure/mcp/tools/relate_tool.ex`
  - Schema: from_id (string, required), to_id (string, required), relationship_type (string, required)
  - Delegates to `CreateKnowledgeRelationship` use case
- [x] **REFACTOR**: Clean up

### Step 2.10: OTP Application & Supervision Tree

- [x] **RED**: Write test `apps/knowledge_mcp/test/knowledge_mcp/otp_app_test.exs`
  - Tests:
    - Application starts successfully
    - Hermes.Server.Registry is started
    - MCP Server is started with streamable_http transport
- [x] **GREEN**: Implement `apps/knowledge_mcp/lib/knowledge_mcp/application.ex`
  - Supervisor with children: `Hermes.Server.Registry`, `{KnowledgeMcp.Infrastructure.Mcp.Server, transport: :streamable_http}`
  - Transport configurable via `config :knowledge_mcp, :mcp_transport`
- [x] **REFACTOR**: Add configuration for port/transport options

### Step 2.11: Router Integration

Configure how the MCP server is accessed via HTTP.

- [x] **RED**: Write integration test `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/router_test.exs`
  - Tests:
    - POST to `/` with no Authorization header returns 401
    - POST to `/` with invalid API key returns 401
    - POST with valid API key forwards to MCP transport (initialize returns server info)
    - Authentication assigns workspace_id and user_id to conn
- [x] **GREEN**: Configure Plug router with auth plug + Hermes forward
  - Defined `KnowledgeMcp.Infrastructure.Mcp.Router` using `Plug.Router`
  - Chains `AuthPlug` before `dispatch`
  - Forwards to `Hermes.Server.Transport.StreamableHTTP.Plug` with server option
- [x] **REFACTOR**: Ensure auth plug is properly composed with Hermes transport

### Phase 2 Validation
- [x] All infrastructure tests pass: `mix test apps/knowledge_mcp/test/knowledge_mcp/infrastructure/` (51 tests)
- [x] All tool tests pass: `mix test apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/` (19 tests)
- [x] Integration tests pass (router_test.exs: 4 tests)
- [x] No boundary violations: `mix compile --warnings-as-errors`
- [x] Full test suite passes: `mix test` in knowledge_mcp app (187 tests)

### Pre-Commit Checkpoint
- [x] `mix compile --warnings-as-errors` passes
- [x] `mix format --check-formatted` passes
- [x] `mix credo --strict` passes (0 issues)
- [x] All knowledge_mcp tests pass: 187 tests, 0 failures
- [ ] ⏸ All tests pass across entire umbrella: `mix test`

---

## Testing Strategy

### Test Distribution

| Layer | Test Count | Async? | Speed | Mocking |
|-------|-----------|--------|-------|---------|
| Domain entities | ~12 | Yes | < 1ms each | None |
| Domain policies | ~30 | Yes | < 1ms each | None |
| Application use cases | ~45 | Yes | < 5ms each | Mox (ErmGatewayMock) |
| Infrastructure (ErmGateway) | ~10 | Depends | < 50ms each | ERM InMemory or Mox |
| Infrastructure (MCP tools) | ~25 | Yes | < 10ms each | Mox |
| Infrastructure (auth plug) | ~8 | Yes | < 5ms each | Mox |
| Integration | ~5 | No | < 500ms each | Minimal |
| **Total** | **~135** | | | |

### Mock Definitions (`test/support/mocks.ex`)

```elixir
Mox.defmock(KnowledgeMcp.Mocks.ErmGatewayMock,
  for: KnowledgeMcp.Application.Behaviours.ErmGatewayBehaviour)
```

### Test Fixtures (`test/support/fixtures.ex`)

```elixir
defmodule KnowledgeMcp.Fixtures do
  alias EntityRelationshipManager.Domain.Entities.{Entity, Edge}

  def workspace_id, do: "ws-test-" <> Ecto.UUID.generate()

  def erm_knowledge_entity(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      workspace_id: workspace_id(),
      type: "KnowledgeEntry",
      properties: %{
        "title" => "Test Entry",
        "body" => "Test body content",
        "category" => "how_to",
        "tags" => Jason.encode!(["elixir", "testing"]),
        "code_snippets" => Jason.encode!([]),
        "file_paths" => Jason.encode!([]),
        "external_links" => Jason.encode!([]),
        "last_verified_at" => nil
      },
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    Entity.new(Map.merge(defaults, overrides))
  end

  def erm_knowledge_edge(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      workspace_id: workspace_id(),
      type: "relates_to",
      source_id: Ecto.UUID.generate(),
      target_id: Ecto.UUID.generate(),
      properties: %{},
      created_at: DateTime.utc_now()
    }

    Edge.new(Map.merge(defaults, overrides))
  end

  def valid_entry_attrs(overrides \\ %{}) do
    Map.merge(%{
      title: "How to add a new context",
      body: "## Steps\n\n1. Create the module...",
      category: "how_to",
      tags: ["architecture", "contexts"],
      code_snippets: [],
      file_paths: ["lib/my_app/my_context.ex"],
      external_links: []
    }, overrides)
  end

  def api_key_entity(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      name: "Test Key",
      user_id: Ecto.UUID.generate(),
      workspace_access: [workspace_id()],
      is_active: true,
      hashed_token: "hashed_test_token"
    }

    Identity.Domain.Entities.ApiKey.new(Map.merge(defaults, overrides))
  end
end
```

### Dependency Injection Pattern

All use cases follow the ERM pattern -- accepting dependencies via `opts`:

```elixir
def execute(workspace_id, attrs, opts \\ []) do
  erm_gateway = Keyword.get(opts, :erm_gateway, default_erm_gateway())
  # ...
end

defp default_erm_gateway do
  Application.get_env(:knowledge_mcp, :erm_gateway, KnowledgeMcp.Infrastructure.ErmGateway)
end
```

This allows:
- Unit tests to inject `ErmGatewayMock` via opts
- Integration tests to use `Application.put_env` for runtime config
- Production to use the real `ErmGateway`

---

## ERM Schema Definition Reference

The knowledge base schema bootstrapped per workspace:

### Entity Type: `KnowledgeEntry`

| Property | ERM Type | Required | Notes |
|----------|----------|----------|-------|
| title | string | Yes | 1-255 chars |
| body | string | Yes | Markdown content |
| category | string | Yes | One of 6 categories |
| tags | string | No | JSON-encoded list of strings |
| code_snippets | string | No | JSON-encoded list of `{language, code, description?}` |
| file_paths | string | No | JSON-encoded list of strings |
| external_links | string | No | JSON-encoded list of `{url, title?}` |
| last_verified_at | string | No | ISO 8601 datetime string |

### Edge Types

| Type | Properties | Notes |
|------|------------|-------|
| relates_to | none | General association |
| depends_on | none | A requires understanding of B |
| prerequisite_for | none | A must be understood before B |
| example_of | none | A is a concrete example of B |
| part_of | none | A is a sub-topic of B |
| supersedes | none | A replaces/updates B |

---

## Acceptance Criteria Mapping

| AC | Phase | Step | Verified By |
|----|-------|------|-------------|
| AC1: Create via MCP | Phase 2 | 2.7 (create tool) + 1.9 (use case) | create_tool_test + create_knowledge_entry_test |
| AC2: Search by keyword | Phase 2 | 2.4 (search tool) + 1.12 (use case) | search_tool_test + search_knowledge_entries_test |
| AC3: Search by tags/category | Phase 2 | 2.4 + 1.12 + 1.5 | search_policy_test + search_knowledge_entries_test |
| AC4: Get by ID with relationships | Phase 2 | 2.5 (get tool) + 1.11 (use case) | get_tool_test + get_knowledge_entry_test |
| AC5: Create relationship | Phase 2 | 2.9 (relate tool) + 1.14 (use case) | relate_tool_test + create_knowledge_relationship_test |
| AC6: Traverse graph | Phase 2 | 2.6 (traverse tool) + 1.13 (use case) | traverse_tool_test + traverse_knowledge_graph_test |
| AC7: Update entry | Phase 2 | 2.8 (update tool) + 1.10 (use case) | update_tool_test + update_knowledge_entry_test |
| AC8: Invalid input errors | Phase 1 | 1.4 (validation policy) + all use cases | knowledge_validation_policy_test + all use case tests |
| AC9: Self-reference rejected | Phase 1 | 1.4 + 1.14 | knowledge_validation_policy_test + create_knowledge_relationship_test |
| AC10: MCP server starts | Phase 2 | 2.10 (OTP app) + 2.3 (server) | otp_app_test + server_test |
| AC11: Workspace-scoped ops | Phase 1 | 1.7 (auth) + all use cases | authenticate_request_test + all use cases pass workspace_id |
| AC12: Auth rejection | Phase 2 | 2.2 (auth plug) + 1.7 (auth use case) | auth_plug_test + authenticate_request_test |
| AC13: Tenant isolation | Phase 2 | 2.11 (integration) | integration_test (workspace scoping via ERM) |

---

## Open Items for Implementation

1. **Hermes MCP version**: Pin to latest stable release of `hermes_mcp` in mix.exs
2. **HTTP port**: Configure MCP server port via application config (default: 4002 or similar)
3. **Router mounting**: Decide whether to mount MCP Plug in the knowledge_mcp app's own Plug pipeline or forward from an existing Phoenix endpoint (recommendation: standalone Plug with Bandit/Cowboy)
4. **ERM InMemory repo for integration tests**: The ERM provides `InMemoryGraphRepository` for testing -- consider using it for knowledge_mcp integration tests instead of full Neo4j
5. **JSON encoding of list properties**: ERM stores properties as `map()` -- list fields (tags, code_snippets, file_paths, external_links) need JSON encoding/decoding at the gateway boundary

## Document Metadata

**Document Prepared By**: Architect Agent
**Date Created**: 2026-02-17
**Last Updated**: 2026-02-17
**Version**: 1.0
**Status**: Ready for Implementation
**Source PRD**: `docs/specs/codebase-knowledge-mcp-prd.md`
