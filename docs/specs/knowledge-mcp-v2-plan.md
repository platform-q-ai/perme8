# Knowledge MCP v2 — TDD Implementation Plan

**Status**: Implemented (branch `refactor/knowledge-mcp-to-agents`, PR #104)

## Overview

Rearchitecture of the knowledge graph MCP functionality from a standalone `apps/knowledge_mcp/` umbrella app into the existing `apps/agents/` app. This consolidation follows reviewer feedback on PR #100 that the knowledge graph is just an ERM schema and MCP is a tool surface for the agents app.

**Source of truth**: See the linked GitHub issue for full requirements

### What changes

1. **DELETE** `apps/knowledge_mcp/` entirely — it becomes dead code
2. **PORT** domain entities, policies, use cases, behaviours, gateway, and MCP infrastructure into `apps/agents/` — adapted to fit the agents app's existing 3-layer boundary structure (`Agents.Domain`, `Agents.Application`, `Agents.Infrastructure`)
3. **UPDATE** boundary configs, OTP supervision, mix deps, and config files in the agents app
4. **CLEAN UP** all references to `knowledge_mcp` across the umbrella

### What stays the same

- All user-facing MCP tool behavior (same 6 tools, same JSON-RPC protocol, same auth flow)
- ERM schema registration (KnowledgeEntry entity type + 6 edge types)
- Domain validation rules (categories, tags, relationship types)
- Search with relevance ranking and graph traversal

## UI Strategy

- **LiveView coverage**: N/A — this feature is MCP-only (no web UI)
- **TypeScript needed**: None — all interaction is via MCP JSON-RPC

## Affected Boundaries

- **Primary context**: `Agents` (receives all new knowledge + MCP modules)
- **Dependencies**: `EntityRelationshipManager` (graph CRUD + traversal), `Identity` (API key verification)
- **Exported entities**: `Agents.Domain.Entities.KnowledgeEntry` and `Agents.Domain.Entities.KnowledgeRelationship` (exported from `Agents.Domain` for cross-boundary use)
- **New context needed?**: No — MCP is the agent's tool exposure surface, and knowledge tools are the first tool set

## Source Module Mapping

| Source (`KnowledgeMcp.*`) | Target (`Agents.*`) |
|---|---|
| `Domain.Entities.KnowledgeEntry` | `Domain.Entities.KnowledgeEntry` |
| `Domain.Entities.KnowledgeRelationship` | `Domain.Entities.KnowledgeRelationship` |
| `Domain.Policies.KnowledgeValidationPolicy` | `Domain.Policies.KnowledgeValidationPolicy` |
| `Domain.Policies.SearchPolicy` | `Domain.Policies.SearchPolicy` |
| `Application.Behaviours.ErmGatewayBehaviour` | `Application.Behaviours.ErmGatewayBehaviour` |
| `Application.Behaviours.IdentityBehaviour` | `Application.Behaviours.IdentityBehaviour` |
| `Application.GatewayConfig` | `Application.GatewayConfig` |
| `Application.UseCases.AuthenticateRequest` | `Application.UseCases.AuthenticateMcpRequest` |
| `Application.UseCases.BootstrapKnowledgeSchema` | `Application.UseCases.BootstrapKnowledgeSchema` |
| `Application.UseCases.CreateKnowledgeEntry` | `Application.UseCases.CreateKnowledgeEntry` |
| `Application.UseCases.UpdateKnowledgeEntry` | `Application.UseCases.UpdateKnowledgeEntry` |
| `Application.UseCases.GetKnowledgeEntry` | `Application.UseCases.GetKnowledgeEntry` |
| `Application.UseCases.SearchKnowledgeEntries` | `Application.UseCases.SearchKnowledgeEntries` |
| `Application.UseCases.TraverseKnowledgeGraph` | `Application.UseCases.TraverseKnowledgeGraph` |
| `Application.UseCases.CreateKnowledgeRelationship` | `Application.UseCases.CreateKnowledgeRelationship` |
| `Infrastructure.ErmGateway` | `Infrastructure.Gateways.ErmGateway` |
| `Infrastructure.Mcp.Server` | `Infrastructure.Mcp.Server` |
| `Infrastructure.Mcp.Router` | `Infrastructure.Mcp.Router` |
| `Infrastructure.Mcp.AuthPlug` | `Infrastructure.Mcp.AuthPlug` |
| `Infrastructure.Mcp.Tools.SearchTool` | `Infrastructure.Mcp.Tools.SearchTool` |
| `Infrastructure.Mcp.Tools.GetTool` | `Infrastructure.Mcp.Tools.GetTool` |
| `Infrastructure.Mcp.Tools.TraverseTool` | `Infrastructure.Mcp.Tools.TraverseTool` |
| `Infrastructure.Mcp.Tools.CreateTool` | `Infrastructure.Mcp.Tools.CreateTool` |
| `Infrastructure.Mcp.Tools.UpdateTool` | `Infrastructure.Mcp.Tools.UpdateTool` |
| `Infrastructure.Mcp.Tools.RelateTool` | `Infrastructure.Mcp.Tools.RelateTool` |

---

## Phase 0: Scaffolding ⏸

> Set up test support, Mox mocks, and mix dependencies before writing any feature code.

### 0.1 Update `apps/agents/mix.exs` — Add Dependencies

Add `hermes_mcp` and `entity_relationship_manager` dependencies:

**File**: `apps/agents/mix.exs`

Add to `deps/0`:
```elixir
{:hermes_mcp, "~> 0.14"},
{:entity_relationship_manager, in_umbrella: true}
```

### 0.2 Create Test Fixtures Module

Port `KnowledgeMcp.Test.Fixtures` → `Agents.Test.KnowledgeFixtures` with namespace changes.

- [ ] ⏸ Create `apps/agents/test/support/fixtures/knowledge_fixtures.ex`
  - Port all fixture functions from `apps/knowledge_mcp/test/support/fixtures.ex`
  - Update namespace references from `KnowledgeMcp.*` to `Agents.*`
  - Functions: `workspace_id/0`, `unique_id/0`, `erm_knowledge_entity/1`, `erm_knowledge_edge/1`, `valid_entry_attrs/1`, `api_key_struct/1`, `schema_definition_with_knowledge/1`

### 0.3 Create Mox Mocks

Register Mox mocks for the new behaviours in the agents test_helper.

- [ ] ⏸ Update `apps/agents/test/test_helper.exs`
  - Add: `Mox.defmock(Agents.Mocks.ErmGatewayMock, for: Agents.Application.Behaviours.ErmGatewayBehaviour)`
  - Add: `Mox.defmock(Agents.Mocks.IdentityMock, for: Agents.Application.Behaviours.IdentityBehaviour)`

### Phase 0 Validation

- [ ] ⏸ `mix deps.get` succeeds
- [ ] ⏸ `mix compile` succeeds (no new warnings)
- [ ] ⏸ Existing agents tests still pass: `mix test --app agents`

---

## Phase 1: Domain Layer ⏸

> Pure domain entities and policies with zero I/O dependencies. All tests use `ExUnit.Case, async: true`.

### 1.1 KnowledgeEntry Entity

Port `KnowledgeMcp.Domain.Entities.KnowledgeEntry` → `Agents.Domain.Entities.KnowledgeEntry`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/entities/knowledge_entry_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/domain/entities/knowledge_entry_test.exs`
  - Tests: `new/1` creates struct with all fields and defaults, `from_erm_entity/1` converts ERM entity maps (handles JSON-encoded lists, nil fields), `to_erm_properties/1` serializes back to ERM property map, `snippet/1` truncates body to 200 chars
  - Use `ExUnit.Case, async: true`
  - Import `Agents.Test.KnowledgeFixtures`
  - ~12 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/entities/knowledge_entry.ex`
  - Pure struct with `defstruct`, `new/1`, `from_erm_entity/1`, `to_erm_properties/1`, `snippet/1`
  - Namespace: `Agents.Domain.Entities.KnowledgeEntry`
  - NOTE: Uses `Jason.encode!/1` and `Jason.decode/1` for list field serialization — this is acceptable in domain entities because it's data transformation, not I/O
- [ ] ⏸ **REFACTOR**: Verify no I/O, no Ecto, no side effects

### 1.2 KnowledgeRelationship Entity

Port `KnowledgeMcp.Domain.Entities.KnowledgeRelationship` → `Agents.Domain.Entities.KnowledgeRelationship`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/entities/knowledge_relationship_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/domain/entities/knowledge_relationship_test.exs`
  - Tests: `new/1` creates struct from attrs, `from_erm_edge/1` converts ERM edge (maps source_id→from_id, target_id→to_id)
  - ~4 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/entities/knowledge_relationship.ex`
  - Pure struct with `defstruct`, `new/1`, `from_erm_edge/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.3 KnowledgeValidationPolicy

Port `KnowledgeMcp.Domain.Policies.KnowledgeValidationPolicy` → `Agents.Domain.Policies.KnowledgeValidationPolicy`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/policies/knowledge_validation_policy_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/domain/policies/knowledge_validation_policy_test.exs`
  - Tests: `valid_category?/1` for all 6 categories + invalid, `valid_relationship_type?/1` for all 6 types + invalid, `validate_entry_attrs/1` (title required, body required, category required, title length), `validate_update_attrs/1` (partial updates, optional category/title validation), `validate_tags/1` (max 20, non-empty strings), `validate_self_reference/2`, `categories/0`, `relationship_types/0`
  - ~22 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/policies/knowledge_validation_policy.ex`
  - Pure functions, no dependencies
- [ ] ⏸ **REFACTOR**: Clean up

### 1.4 SearchPolicy

Port `KnowledgeMcp.Domain.Policies.SearchPolicy` → `Agents.Domain.Policies.SearchPolicy`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/policies/search_policy_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/domain/policies/search_policy_test.exs`
  - Tests: `validate_search_params/1` (requires at least one criteria, validates category, clamps limit to 1..100), `score_relevance/2` (title match > body match, case-insensitive), `matches_tags?/2` (AND logic, nil/empty returns true), `matches_category?/2` (nil returns true), `clamp_depth/1` (1..5 range, default 2)
  - ~18 tests
  - Update alias from `KnowledgeMcp.Domain.*` to `Agents.Domain.*`
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/policies/search_policy.ex`
  - Pure functions, depends only on `Agents.Domain.Entities.KnowledgeEntry` and `Agents.Domain.Policies.KnowledgeValidationPolicy`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.5 Update `Agents.Domain` Boundary

- [ ] ⏸ Update `apps/agents/lib/agents/domain.ex`
  - Add exports: `Entities.KnowledgeEntry`, `Entities.KnowledgeRelationship`, `Policies.KnowledgeValidationPolicy`, `Policies.SearchPolicy`

### Phase 1 Validation

- [ ] ⏸ All domain tests pass: `mix test apps/agents/test/agents/domain/` (milliseconds, no I/O)
- [ ] ⏸ `mix compile --warnings-as-errors` passes for agents app
- [ ] ⏸ ~56 new domain tests

---

## Phase 2: Application Layer ⏸

> Behaviours, gateway config, and use cases. Tests use `ExUnit.Case, async: true` with Mox for dependency injection.

### 2.1 ErmGatewayBehaviour

Port `KnowledgeMcp.Application.Behaviours.ErmGatewayBehaviour` → `Agents.Application.Behaviours.ErmGatewayBehaviour`

- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/behaviours/erm_gateway_behaviour.ex`
  - Behaviour with 10 callbacks: `get_schema/1`, `upsert_schema/2`, `create_entity/2`, `get_entity/2`, `update_entity/3`, `list_entities/2`, `create_edge/2`, `list_edges/2`, `get_neighbors/3`, `traverse/3`
  - No test needed (it's a behaviour definition — tested transitively via use case tests)

### 2.2 IdentityBehaviour

Port `KnowledgeMcp.Application.Behaviours.IdentityBehaviour` → `Agents.Application.Behaviours.IdentityBehaviour`

- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/behaviours/identity_behaviour.ex`
  - Behaviour with 1 callback: `verify_api_key/1`
  - References `Identity.Domain.Entities.ApiKey` type
  - No test needed (behaviour definition)

### 2.3 GatewayConfig

Port `KnowledgeMcp.Application.GatewayConfig` → `Agents.Application.GatewayConfig`

- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/gateway_config.ex`
  - `erm_gateway/0` — reads from `:agents` app config, defaults to `Agents.Infrastructure.Gateways.ErmGateway`
  - `identity_module/0` — reads from `:agents` app config, defaults to `Identity`
  - Uses `Application.get_env(:agents, ...)` instead of `:knowledge_mcp`
  - No test needed (configuration accessor — tested transitively)

### 2.4 AuthenticateMcpRequest Use Case

Port `KnowledgeMcp.Application.UseCases.AuthenticateRequest` → `Agents.Application.UseCases.AuthenticateMcpRequest`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/authenticate_mcp_request_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/authenticate_request_test.exs`
  - Tests: valid token returns `{:ok, %{workspace_id, user_id}}`, invalid token returns `{:error, :unauthorized}`, inactive token returns `{:error, :unauthorized}`, no workspace access returns `{:error, :no_workspace_access}`, nil workspace_access returns `{:error, :no_workspace_access}`
  - Mocks: `Agents.Mocks.IdentityMock`
  - ~5 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/authenticate_mcp_request.ex`
  - DI via `opts[:identity_module]`, defaults to `GatewayConfig.identity_module()`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.5 BootstrapKnowledgeSchema Use Case

Port `KnowledgeMcp.Application.UseCases.BootstrapKnowledgeSchema` → `Agents.Application.UseCases.BootstrapKnowledgeSchema`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/bootstrap_knowledge_schema_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/bootstrap_knowledge_schema_test.exs`
  - Tests: returns `{:ok, :already_bootstrapped}` when schema exists with KnowledgeEntry, creates schema when none exists, merges with existing schema that lacks KnowledgeEntry, propagates ERM gateway errors
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~6 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/bootstrap_knowledge_schema.ex`
  - DI via `opts[:erm_gateway]`, defaults to `GatewayConfig.erm_gateway()`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.6 CreateKnowledgeEntry Use Case

Port `KnowledgeMcp.Application.UseCases.CreateKnowledgeEntry` → `Agents.Application.UseCases.CreateKnowledgeEntry`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/create_knowledge_entry_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/create_knowledge_entry_test.exs`
  - Tests: creates entry with valid attrs, calls bootstrap first, creates ERM entity with type "KnowledgeEntry" and JSON-encoded properties, validation errors (title_required, body_required, invalid_category, too_many_tags), converts ERM entity response back to domain entity
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~7 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/create_knowledge_entry.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.7 UpdateKnowledgeEntry Use Case

Port `KnowledgeMcp.Application.UseCases.UpdateKnowledgeEntry` → `Agents.Application.UseCases.UpdateKnowledgeEntry`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/update_knowledge_entry_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/update_knowledge_entry_test.exs`
  - Tests: updates entry with partial attrs, merges with existing properties (only overwrites provided fields), validation errors (title_too_long, invalid_category), returns not_found for missing entity
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~6 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/update_knowledge_entry.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.8 GetKnowledgeEntry Use Case

Port `KnowledgeMcp.Application.UseCases.GetKnowledgeEntry` → `Agents.Application.UseCases.GetKnowledgeEntry`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/get_knowledge_entry_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/get_knowledge_entry_test.exs`
  - Tests: returns entry with relationships, converts ERM entity+edges to domain types, returns not_found
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~4 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/get_knowledge_entry.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.9 SearchKnowledgeEntries Use Case

Port `KnowledgeMcp.Application.UseCases.SearchKnowledgeEntries` → `Agents.Application.UseCases.SearchKnowledgeEntries`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/search_knowledge_entries_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/search_knowledge_entries_test.exs`
  - Tests: validates search params via SearchPolicy, lists all KnowledgeEntry entities from ERM, filters by tags (AND logic) and category, scores and sorts by relevance (title > body), respects limit, truncates body in results, returns empty list for no matches, returns error for empty search
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~9 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/search_knowledge_entries.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.10 TraverseKnowledgeGraph Use Case

Port `KnowledgeMcp.Application.UseCases.TraverseKnowledgeGraph` → `Agents.Application.UseCases.TraverseKnowledgeGraph`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/traverse_knowledge_graph_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/traverse_knowledge_graph_test.exs`
  - Tests: traverses from start entry with depth, filters by relationship type, clamps depth to 1..5, validates relationship type, returns not_found for missing start entity
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~7 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/traverse_knowledge_graph.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.11 CreateKnowledgeRelationship Use Case

Port `KnowledgeMcp.Application.UseCases.CreateKnowledgeRelationship` → `Agents.Application.UseCases.CreateKnowledgeRelationship`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/create_knowledge_relationship_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/application/use_cases/create_knowledge_relationship_test.exs`
  - Tests: creates edge between two entries, validates relationship type, rejects self-reference, bootstraps schema first, verifies both entries exist, returns not_found when entry missing
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~8 tests
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/create_knowledge_relationship.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.12 Update `Agents.Application` Boundary

- [ ] ⏸ Update `apps/agents/lib/agents/application.ex`
  - Add exports for new use cases: `UseCases.AuthenticateMcpRequest`, `UseCases.BootstrapKnowledgeSchema`, `UseCases.CreateKnowledgeEntry`, `UseCases.UpdateKnowledgeEntry`, `UseCases.GetKnowledgeEntry`, `UseCases.SearchKnowledgeEntries`, `UseCases.TraverseKnowledgeGraph`, `UseCases.CreateKnowledgeRelationship`
  - Add exports for new behaviours: `Behaviours.ErmGatewayBehaviour`, `Behaviours.IdentityBehaviour`
  - Add export: `GatewayConfig`

### Phase 2 Validation

- [ ] ⏸ All application tests pass with mocks: `mix test apps/agents/test/agents/application/`
- [ ] ⏸ `mix compile --warnings-as-errors` passes
- [ ] ⏸ ~52 new application tests

---

## Phase 3: Infrastructure Layer ✓

> ERM gateway adapter, MCP server/router/auth, and tool components. Tests use `ExUnit.Case` (some async: false for router tests with Application.put_env).

### 3.1 ErmGateway

Port `KnowledgeMcp.Infrastructure.ErmGateway` → `Agents.Infrastructure.Gateways.ErmGateway`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/gateways/erm_gateway_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/erm_gateway_test.exs`
  - Tests: each callback delegates to `EntityRelationshipManager` facade (verify function_exported? for all 10 callbacks, verify `@behaviour Agents.Application.Behaviours.ErmGatewayBehaviour`)
  - ~3 tests (module structure tests — actual delegation tested via integration)
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/gateways/erm_gateway.ex`
  - Thin adapter: `@behaviour Agents.Application.Behaviours.ErmGatewayBehaviour`
  - Each callback delegates to `EntityRelationshipManager.*`
- [x] ✓ **REFACTOR**: Clean up

### 3.2 MCP AuthPlug

Port `KnowledgeMcp.Infrastructure.Mcp.AuthPlug` → `Agents.Infrastructure.Mcp.AuthPlug`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/auth_plug_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/auth_plug_test.exs`
  - Tests: extracts Bearer token and authenticates (assigns workspace_id + user_id), case-insensitive Bearer prefix, 401 for missing auth header, 401 for invalid token, 401 for inactive token, 401 for non-Bearer scheme, 401 for no workspace access
  - Mocks: `Agents.Mocks.IdentityMock`
  - ~7 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/auth_plug.ex`
  - `@behaviour Plug`
  - Uses `Agents.Application.UseCases.AuthenticateMcpRequest`
  - Accepts `:identity_module` option for DI
- [x] ✓ **REFACTOR**: Clean up

### 3.3 MCP Server

Port `KnowledgeMcp.Infrastructure.Mcp.Server` → `Agents.Infrastructure.Mcp.Server`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/server_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/server_test.exs`
  - Tests: defines `init/2` callback, registers all 6 tool components, each tool name registered (knowledge.search, knowledge.get, knowledge.traverse, knowledge.create, knowledge.update, knowledge.relate), server name is "knowledge-mcp", server version is "1.0.0"
  - ~9 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/server.ex`
  - `use Hermes.Server, name: "knowledge-mcp", version: "1.0.0", capabilities: [:tools]`
  - Register 6 tool components
- [x] ✓ **REFACTOR**: Clean up

### 3.4 MCP Router

Port `KnowledgeMcp.Infrastructure.Mcp.Router` → `Agents.Infrastructure.Mcp.Router`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/router_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/router_test.exs`
  - Tests: returns 401 for unauthenticated requests, forwards authenticated requests to MCP transport (receives 200 with server info), assigns workspace_id and user_id from auth
  - Mocks: `Agents.Mocks.IdentityMock`
  - `async: false` (uses `Application.put_env`)
  - ~4 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/router.ex`
  - `use Plug.Router`
  - Composes AuthPlug + Hermes StreamableHTTP transport
- [x] ✓ **REFACTOR**: Clean up

### 3.5 SearchTool

Port `KnowledgeMcp.Infrastructure.Mcp.Tools.SearchTool` → `Agents.Infrastructure.Mcp.Tools.SearchTool`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/search_tool_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/search_tool_test.exs`
  - Tests: returns formatted results for successful search, returns "No results found." for empty results, returns error for empty search criteria, formats results with numbering/title/category/tags/body
  - Mocks: `Agents.Mocks.ErmGatewayMock` (called indirectly via use case)
  - ~5 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/search_tool.ex`
  - `use Hermes.Server.Component, type: :tool`
  - Schema: query, tags, category, limit
  - Delegates to `Agents.Application.UseCases.SearchKnowledgeEntries`
- [x] ✓ **REFACTOR**: Clean up

### 3.6 GetTool

Port `KnowledgeMcp.Infrastructure.Mcp.Tools.GetTool` → `Agents.Infrastructure.Mcp.Tools.GetTool`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/get_tool_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/get_tool_test.exs`
  - Tests: returns formatted entry with relationships, returns error for not_found, formats entry with title/category/tags/body/relationships
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~4 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/get_tool.ex`
- [x] ✓ **REFACTOR**: Clean up

### 3.7 TraverseTool

Port `KnowledgeMcp.Infrastructure.Mcp.Tools.TraverseTool` → `Agents.Infrastructure.Mcp.Tools.TraverseTool`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/traverse_tool_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/traverse_tool_test.exs`
  - Tests: returns formatted traversal results, returns "No connected entries" for empty, returns error for not_found, returns error for invalid relationship type
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~5 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/traverse_tool.ex`
- [x] ✓ **REFACTOR**: Clean up

### 3.8 CreateTool

Port `KnowledgeMcp.Infrastructure.Mcp.Tools.CreateTool` → `Agents.Infrastructure.Mcp.Tools.CreateTool`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/create_tool_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/create_tool_test.exs`
  - Tests: returns formatted success for valid create, returns validation errors (title_required, body_required, invalid_category, title_too_long, too_many_tags, invalid_tag)
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~7 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/create_tool.ex`
- [x] ✓ **REFACTOR**: Clean up

### 3.9 UpdateTool

Port `KnowledgeMcp.Infrastructure.Mcp.Tools.UpdateTool` → `Agents.Infrastructure.Mcp.Tools.UpdateTool`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/update_tool_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/update_tool_test.exs`
  - Tests: returns formatted success for valid update, strips nil fields from params, returns error for not_found, returns error for invalid_category
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~5 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/update_tool.ex`
- [x] ✓ **REFACTOR**: Clean up

### 3.10 RelateTool

Port `KnowledgeMcp.Infrastructure.Mcp.Tools.RelateTool` → `Agents.Infrastructure.Mcp.Tools.RelateTool`

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/relate_tool_test.exs`
  - Port from: `apps/knowledge_mcp/test/knowledge_mcp/infrastructure/mcp/tools/relate_tool_test.exs`
  - Tests: returns formatted success for valid relationship, returns error for self-reference, returns error for invalid_relationship_type, returns error for not_found entries
  - Mocks: `Agents.Mocks.ErmGatewayMock`
  - ~5 tests
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/relate_tool.ex`
- [x] ✓ **REFACTOR**: Clean up

### 3.11 Update `Agents.Infrastructure` Boundary

- [x] ✓ Update `apps/agents/lib/agents/infrastructure.ex`
  - Add dep: `EntityRelationshipManager` (for ErmGateway to call ERM facade)
  - Add exports: `Gateways.ErmGateway`, `Mcp.Server`, `Mcp.Router`, `Mcp.AuthPlug`
  - Tool modules are internal (NOT exported — only the Server references them)

### Phase 3 Validation

- [x] ✓ All infrastructure tests pass: `mix test apps/agents/test/agents/infrastructure/` (98 tests)
- [x] ✓ `mix compile` passes
- [x] ✓ 98 new infrastructure tests (51 infra-specific + gateway + server + router)

---

## Phase 4: Integration ⏸

> OTP supervision, top-level boundary config, Agents facade additions, and config updates.

### 4.1 Update OTP Supervisor

- [ ] ⏸ Update `apps/agents/lib/agents/otp_app.ex`
  - Add `Hermes.Server.Registry` as child
  - Add `{Agents.Infrastructure.Mcp.Server, transport: mcp_transport()}` as child
  - Add private `mcp_transport/0` function: `Application.get_env(:agents, :mcp_transport, {:streamable_http, []})`

### 4.2 Update Agents Facade

- [ ] ⏸ Update `apps/agents/lib/agents.ex`
  - Add boundary dep: `EntityRelationshipManager`
  - Add knowledge facade functions that delegate to use cases:
    - `authenticate_mcp/2` → `AuthenticateMcpRequest.execute/2`
    - `create_knowledge_entry/3` → `CreateKnowledgeEntry.execute/3`
    - `update_knowledge_entry/4` → `UpdateKnowledgeEntry.execute/4`
    - `get_knowledge_entry/3` → `GetKnowledgeEntry.execute/3`
    - `search_knowledge_entries/3` → `SearchKnowledgeEntries.execute/3`
    - `traverse_knowledge_graph/3` → `TraverseKnowledgeGraph.execute/3`
    - `create_knowledge_relationship/3` → `CreateKnowledgeRelationship.execute/3`
    - `bootstrap_knowledge_schema/2` → `BootstrapKnowledgeSchema.execute/2`

### 4.3 Update Config Files

- [ ] ⏸ Update `config/test.exs`
  - **Remove**: `config :knowledge_mcp, :mcp_transport, {:streamable_http, start: true}`
  - **Add**: `config :agents, :mcp_transport, {:streamable_http, start: true}`
  - **Add**: `config :agents, :erm_gateway, Agents.Mocks.ErmGatewayMock` (optional — can rely on opts DI instead)
  - **Add**: `config :agents, :identity_module, Agents.Mocks.IdentityMock` (optional — can rely on opts DI instead)

### 4.4 Facade Integration Test

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/knowledge_facade_test.exs`
  - Tests: facade functions exist and delegate correctly (verify function_exported? for all 8 knowledge functions)
  - ~8 tests
- [ ] ⏸ **GREEN**: Facade functions already implemented in 4.2
- [ ] ⏸ **REFACTOR**: Verify facade is thin (just delegation)

### Phase 4 Validation

- [ ] ⏸ All agents tests pass: `mix test --app agents`
- [ ] ⏸ `mix compile --warnings-as-errors` passes
- [ ] ⏸ `mix boundary` passes with no violations
- [ ] ⏸ OTP supervisor starts successfully (verify in IEx: `Application.started_applications()`)

---

## Phase 5: Cleanup & Verification ⏸

> Delete the old app, clean up all references, and verify the full test suite.

### 5.1 Delete `apps/knowledge_mcp/`

- [ ] ⏸ Delete the entire `apps/knowledge_mcp/` directory
  - `rm -rf apps/knowledge_mcp`

### 5.2 Clean Up Config References

- [ ] ⏸ Remove any remaining `:knowledge_mcp` config entries from:
  - `config/config.exs` (if any)
  - `config/dev.exs` (if any)
  - `config/test.exs` (the line was already replaced in 4.3)
  - `config/prod.exs` (if any)
  - `config/runtime.exs` (if any)

### 5.3 Clean Up CI/CD References

- [ ] ⏸ Search for `knowledge_mcp` or `knowledge-mcp` in:
  - `.github/workflows/*.yml` (if any)
  - `Makefile` (if any)
  - `mix.exs` (root umbrella)
  - Any other build/deploy scripts

### 5.4 Verify No Dangling References

- [ ] ⏸ Run: `grep -r "KnowledgeMcp\|knowledge_mcp\|knowledge-mcp" apps/ config/ --include="*.ex" --include="*.exs" --include="*.yml"` — should return nothing (or only this plan doc)

### Phase 5 Validation

- [ ] ⏸ `mix deps.get` succeeds
- [ ] ⏸ `mix compile --warnings-as-errors` succeeds across entire umbrella
- [ ] ⏸ `mix boundary` passes with no violations
- [ ] ⏸ `mix test` — full umbrella test suite passes
- [ ] ⏸ `mix precommit` passes

---

## Pre-Commit Checkpoint

After all phases complete:

- [ ] ⏸ `mix precommit` (compilation + boundary + formatting + credo + tests)
- [ ] ⏸ `mix boundary` (no violations in any app)
- [ ] ⏸ All acceptance criteria from ticket verified:
  - AC1: `knowledge_mcp` umbrella app removed ✓
  - AC2: Knowledge schema registered in ERM (bootstrap use case) ✓
  - AC3: Agents app exposes MCP endpoint with 6 tools ✓
  - AC4: MCP tools authenticate via Identity API keys ✓
  - AC5: All operations workspace-scoped via API key ✓
  - AC6: Tool registration is configuration-driven ✓
  - AC7: All validation works correctly ✓
  - AC8: Search returns results sorted by relevance ✓
  - AC9: Graph traversal with configurable depth ✓
  - AC10: All tests pass ✓
  - AC11: Boundary checks pass ✓
  - AC12: Pre-commit checks pass ✓

---

## Testing Strategy

### Test Distribution

| Layer | Test File Count | Estimated Tests | Test Type |
|---|---|---|---|
| Domain (entities) | 2 | ~16 | `ExUnit.Case, async: true` |
| Domain (policies) | 2 | ~40 | `ExUnit.Case, async: true` |
| Application (use cases) | 8 | ~52 | `ExUnit.Case, async: true` + Mox |
| Infrastructure (gateway) | 1 | ~3 | `ExUnit.Case, async: true` |
| Infrastructure (MCP auth) | 1 | ~7 | `ExUnit.Case, async: true` + Mox |
| Infrastructure (MCP server) | 1 | ~9 | `ExUnit.Case, async: true` |
| Infrastructure (MCP router) | 1 | ~4 | `ExUnit.Case, async: false` + Mox |
| Infrastructure (MCP tools) | 6 | ~31 | `ExUnit.Case, async: true` + Mox |
| Integration (facade) | 1 | ~8 | `ExUnit.Case, async: true` |
| **Total** | **23** | **~170** | |

### Testing Approach

- **Domain tests**: Pure function tests, no mocks needed, millisecond execution
- **Application tests**: Mox mocks for ErmGatewayBehaviour and IdentityBehaviour, verify orchestration logic
- **Infrastructure tests**: Mox for auth plug and tools (mock via Application.put_env or opts), Plug.Test for HTTP-level testing of auth plug and router
- **No database tests needed**: All data goes through ERM (mocked), no Ecto schemas in agents for knowledge
- **Port strategy**: Each test file is ported from the corresponding `knowledge_mcp` test, with namespace changes and updated mock references

### Key Mock Modules

| Mock | Behaviour | Used By |
|---|---|---|
| `Agents.Mocks.ErmGatewayMock` | `Agents.Application.Behaviours.ErmGatewayBehaviour` | All knowledge use cases, tools |
| `Agents.Mocks.IdentityMock` | `Agents.Application.Behaviours.IdentityBehaviour` | AuthenticateMcpRequest, AuthPlug, Router |

---

## File Index

### New Files to Create (in `apps/agents/`)

```
lib/agents/domain/entities/knowledge_entry.ex
lib/agents/domain/entities/knowledge_relationship.ex
lib/agents/domain/policies/knowledge_validation_policy.ex
lib/agents/domain/policies/search_policy.ex
lib/agents/application/behaviours/erm_gateway_behaviour.ex
lib/agents/application/behaviours/identity_behaviour.ex
lib/agents/application/gateway_config.ex
lib/agents/application/use_cases/authenticate_mcp_request.ex
lib/agents/application/use_cases/bootstrap_knowledge_schema.ex
lib/agents/application/use_cases/create_knowledge_entry.ex
lib/agents/application/use_cases/update_knowledge_entry.ex
lib/agents/application/use_cases/get_knowledge_entry.ex
lib/agents/application/use_cases/search_knowledge_entries.ex
lib/agents/application/use_cases/traverse_knowledge_graph.ex
lib/agents/application/use_cases/create_knowledge_relationship.ex
lib/agents/infrastructure/gateways/erm_gateway.ex
lib/agents/infrastructure/mcp/auth_plug.ex
lib/agents/infrastructure/mcp/server.ex
lib/agents/infrastructure/mcp/router.ex
lib/agents/infrastructure/mcp/tools/search_tool.ex
lib/agents/infrastructure/mcp/tools/get_tool.ex
lib/agents/infrastructure/mcp/tools/traverse_tool.ex
lib/agents/infrastructure/mcp/tools/create_tool.ex
lib/agents/infrastructure/mcp/tools/update_tool.ex
lib/agents/infrastructure/mcp/tools/relate_tool.ex
test/support/fixtures/knowledge_fixtures.ex
test/agents/domain/entities/knowledge_entry_test.exs
test/agents/domain/entities/knowledge_relationship_test.exs
test/agents/domain/policies/knowledge_validation_policy_test.exs
test/agents/domain/policies/search_policy_test.exs
test/agents/application/use_cases/authenticate_mcp_request_test.exs
test/agents/application/use_cases/bootstrap_knowledge_schema_test.exs
test/agents/application/use_cases/create_knowledge_entry_test.exs
test/agents/application/use_cases/update_knowledge_entry_test.exs
test/agents/application/use_cases/get_knowledge_entry_test.exs
test/agents/application/use_cases/search_knowledge_entries_test.exs
test/agents/application/use_cases/traverse_knowledge_graph_test.exs
test/agents/application/use_cases/create_knowledge_relationship_test.exs
test/agents/infrastructure/gateways/erm_gateway_test.exs
test/agents/infrastructure/mcp/auth_plug_test.exs
test/agents/infrastructure/mcp/server_test.exs
test/agents/infrastructure/mcp/router_test.exs
test/agents/infrastructure/mcp/tools/search_tool_test.exs
test/agents/infrastructure/mcp/tools/get_tool_test.exs
test/agents/infrastructure/mcp/tools/traverse_tool_test.exs
test/agents/infrastructure/mcp/tools/create_tool_test.exs
test/agents/infrastructure/mcp/tools/update_tool_test.exs
test/agents/infrastructure/mcp/tools/relate_tool_test.exs
test/agents/knowledge_facade_test.exs
```

### Files to Modify

```
lib/agents.ex                    — Add boundary dep, knowledge facade functions
lib/agents/domain.ex             — Add exports for knowledge entities + policies
lib/agents/application.ex        — Add exports for knowledge use cases + behaviours
lib/agents/infrastructure.ex     — Add exports for gateway + MCP modules, add ERM dep
lib/agents/otp_app.ex            — Add MCP server supervision
mix.exs                          — Add hermes_mcp + entity_relationship_manager deps
test/test_helper.exs             — Add Mox mock definitions
config/test.exs                  — Replace knowledge_mcp config with agents config
```

### Files to Delete

```
apps/knowledge_mcp/              — Entire directory (rm -rf)
```

---

## Document Metadata

**Version**: 1.0
**Date**: 2026-02-17
**Status**: Ready for implementation
**Ticket**: See linked GitHub issue
**Related**: PR #100, Issues #97, #98, #99
