# Feature: API Permissions Management per API Key

**Ticket:** #56 — Add API permissions management per API key
**Ticket:** `docs/agents/tickets/api-permissions-ticket.md`
**BDD Feature Files:**
- `apps/identity/test/features/api-permissions/api-permissions.browser.feature` (9 scenarios)
- `apps/agents_api/test/features/api-permissions/api-permissions.http.feature` (14 scenarios)
- `apps/agents_api/test/features/api-permissions/api-permissions.security.feature` (10 scenarios)

## App Ownership

- **Primary owning app (domain)**: `identity`
- **Owning Repo**: `Identity.Repo`
- **Domain code path**: `apps/identity/lib/identity/`
- **Web code path**: `apps/identity/lib/identity_web/`
- **Migrations path**: `apps/identity/priv/repo/migrations/`
- **Domain tests path**: `apps/identity/test/identity/`
- **Web tests path**: `apps/identity/test/identity_web/`
- **Browser BDD feature files**: `apps/identity/test/features/api-permissions/`
- **Consuming app (MCP enforcement)**: `agents` — `apps/agents/lib/agents/`
- **Consuming app (REST enforcement)**: `agents_api` — `apps/agents_api/lib/agents_api/`
- **HTTP BDD feature files**: `apps/agents_api/test/features/api-permissions/`
- **Security BDD feature files**: `apps/agents_api/test/features/api-permissions/`

**Placement rules (from `docs/app_ownership.md`):**
- ALL domain artifacts (migration, entity, policy, schema, use case, repository, facade) → `identity` app
- Identity LiveView UI → `identity_web` (inside `apps/identity/lib/identity_web/`)
- REST permission plug → `agents_api` app (interface-layer enforcement only)
- MCP permission check → `agents` app (infrastructure-layer enforcement only)
- `agents` and `agents_api` NEVER access `Identity.Repo` directly — they consume `Identity.*` facade functions

## Overview

Add a `permissions` field to API keys enabling granular scope-based access control. API keys can be assigned permission scopes like `agents:read`, `mcp:knowledge.*`, or `*` (full access). Existing keys with `nil` permissions retain full access for backward compatibility. The permission model is purely additive (allow-list, no deny rules).

The implementation spans four apps:
1. **`identity`** — Domain model, policy, schema, use cases, facade (owner)
2. **`identity_web`** — LiveView UI for permission management (interface)
3. **`agents_api`** — REST API permission plug enforcement (consumer)
4. **`agents`** — MCP tool permission enforcement (consumer)

## UI Strategy

- **LiveView coverage**: 100% — permission presets, custom scope checkboxes, badges, and warnings are all server-rendered
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `identity`
- **Repo**: `Identity.Repo`
- **Migrations**: `apps/identity/priv/repo/migrations/`
- **Feature files**: See listing above
- **Primary context**: `Identity` (API keys are managed within the Identity bounded context)
- **Dependencies called via public API**: `Identity.api_key_has_permission?/2` consumed by `agents` and `agents_api`
- **Exported schemas/entities**: `Identity.Domain.Entities.ApiKey` (already exported, gains `permissions` field), `Identity.Domain.Policies.ApiKeyPermissionPolicy` (new export)
- **New context needed?**: No — permissions are an attribute of API keys, which already belong to Identity

---

## Phase 1: Identity Domain — Entity, Policy, Scopes (phoenix-tdd)

> Pure domain layer. No I/O, no database. All tests run with `ExUnit.Case, async: true`.

### 1.1 ApiKeyPermissionPolicy — Permission Scope Matching

The core pure-function policy implementing wildcard-aware scope matching. This is the
foundation — everything else depends on it.

- [x] ⏸ **RED**: Write test `apps/identity/test/identity/domain/policies/api_key_permission_policy_test.exs`
  - Tests:
    - `has_permission?/2` with `nil` permissions returns `true` (backward compat)
    - `has_permission?/2` with `["*"]` returns `true` for any scope
    - `has_permission?/2` with `["agents:read"]` returns `true` for `"agents:read"`, `false` for `"agents:write"`
    - `has_permission?/2` with `["mcp:knowledge.*"]` returns `true` for `"mcp:knowledge.search"`, `"mcp:knowledge.get"`, `false` for `"mcp:jarga.list_workspaces"`
    - `has_permission?/2` with `["mcp:*"]` returns `true` for `"mcp:knowledge.search"`, `"mcp:jarga.list_workspaces"`, `false` for `"agents:read"`
    - `has_permission?/2` with `["agents:*"]` returns `true` for `"agents:read"`, `"agents:write"`, `"agents:query"`, `false` for `"mcp:knowledge.search"`
    - `has_permission?/2` with `[]` (empty list) returns `false` for any scope
    - `has_permission?/2` with multiple specific scopes matches each one
    - `permission_summary/1` returns `:full_access` for `nil` or `["*"]`
    - `permission_summary/1` returns `:no_access` for `[]`
    - `permission_summary/1` returns `:read_only` for the read-only preset scope list
    - `permission_summary/1` returns `:agent_operator` for the agent-operator preset scope list
    - `permission_summary/1` returns `{:custom, count}` for other scope combinations
    - `valid_scope?/1` validates format `^(\*|[a-z_]+:[a-z_.*]+)$`
    - `presets/0` returns the defined preset map
    - `all_scopes/0` returns the canonical registry of all known scopes
- [x] ⏸ **GREEN**: Implement `apps/identity/lib/identity/domain/policies/api_key_permission_policy.ex`
  - Pure functions, no I/O
  - `has_permission?(permissions, required_scope)` — core matching with wildcard support
  - `permission_summary(permissions)` — categorizes permission level for UI display
  - `valid_scope?(scope)` — validates format
  - `presets/0` — returns map of preset name → scope list
  - `all_scopes/0` — canonical scope registry (REST + MCP)
  - Scope matching rules: nil → full access, `"*"` matches all, exact match, `"resource:*"` suffix wildcard, `"mcp:category.*"` nested wildcard
- [x] ⏸ **REFACTOR**: Ensure single responsibility — this module owns ONLY scope matching logic, no I/O

### 1.2 ApiKey Domain Entity — Add `permissions` Field

- [x] ⏸ **RED**: Update test `apps/identity/test/identity/domain/entities/api_key_test.exs`
  - Tests:
    - `new/1` accepts `permissions` field (list of strings or nil)
    - `from_schema/1` maps `permissions` field correctly (including nil → nil)
    - Struct includes `permissions` key with default nil
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity/domain/entities/api_key.ex`
  - Add `permissions: [String.t()] | nil` to `@type t`, `defstruct`, and `from_schema/1`
- [x] ⏸ **REFACTOR**: Keep entity as pure data mapping, no logic

### Phase 1 Validation

- [x] ⏸ All domain policy tests pass: `mix test apps/identity/test/identity/domain/policies/api_key_permission_policy_test.exs`
- [x] ⏸ All entity tests pass: `mix test apps/identity/test/identity/domain/entities/api_key_test.exs`
- [x] ⏸ Tests run in milliseconds (no I/O, no DB)
- [ ] ⏸ No boundary violations: `mix boundary`

---

## Phase 2: Identity Infrastructure — Schema, Migration, Repository (phoenix-tdd) ✓

> Infrastructure layer. Tests use `Identity.DataCase`.

### 2.1 Migration — Add `permissions` Column

- [x] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/[timestamp]_add_permissions_to_api_keys.exs`
  - Add `permissions` column to `api_keys` table: `{:array, :string}`, nullable, default `nil`
  - No data migration needed — existing rows with `nil` are treated as full access

### 2.2 ApiKeySchema — Add `permissions` Field and Changeset

- [x] ⏸ **RED**: Update test `apps/identity/test/identity/infrastructure/schemas/api_key_schema_test.exs`
  - Tests:
    - Schema has `permissions` field (`:array, :string`)
    - `changeset/2` casts `permissions` attribute
    - `changeset/2` accepts `nil` for permissions (backward compat)
    - `changeset/2` accepts empty list `[]` for permissions
    - `changeset/2` accepts valid scope strings list
    - `changeset/2` validates max 100 permissions (length constraint)
    - `to_entity/1` includes `permissions` in the mapped entity
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity/infrastructure/schemas/api_key_schema.ex`
  - Add `field(:permissions, {:array, :string})` to schema (no default — nil by default)
  - Add `:permissions` to `changeset/2` cast list
  - Add `validate_length(:permissions, max: 100)` constraint
  - Update `to_entity/1` to include `permissions` field
- [x] ⏸ **REFACTOR**: Keep changeset focused on cast/validation only

### 2.3 ApiKeyRepository — Pass Through `permissions` in Insert/Update

- [x] ⏸ **RED**: Update test `apps/identity/test/identity/infrastructure/repositories/api_key_repository_test.exs`
  - Tests:
    - `insert/2` with permissions attribute stores and returns permissions
    - `insert/2` without permissions stores nil
    - `update/3` with permissions attribute updates and returns permissions
    - `get_by_id/2` returns entity with permissions field
    - `get_by_hashed_token/2` returns entity with permissions field
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity/infrastructure/repositories/api_key_repository.ex`
  - No functional changes needed — the repository delegates to schema changeset which now handles `permissions`
  - Verify that `insert`, `update`, `get_by_id`, `get_by_hashed_token` all correctly flow permissions through
- [x] ⏸ **REFACTOR**: Confirm thin wrapper principle — no business logic in repository

### Phase 2 Validation

- [x] ⏸ Migration runs: `mix ecto.migrate`
- [x] ⏸ All schema tests pass: `mix test apps/identity/test/identity/infrastructure/schemas/api_key_schema_test.exs`
- [x] ⏸ All repository tests pass: `mix test apps/identity/test/identity/infrastructure/repositories/api_key_repository_test.exs`
- [x] ⏸ No boundary violations: `mix boundary` (task unavailable; verified via `mix compile` and no boundary warnings)

---

## Phase 3: Identity Application — Use Cases and Facade (phoenix-tdd) ✓

> Application layer. Tests use `Identity.DataCase` with mocked dependencies via opts.

### 3.1 CreateApiKey Use Case — Accept `permissions` Attribute

- [x] ⏸ **RED**: Update test `apps/identity/test/identity/application/use_cases/create_api_key_test.exs`
  - Tests:
    - Creating with `permissions: ["agents:read", "mcp:knowledge.*"]` stores permissions on key
    - Creating without `permissions` key stores `nil` (backward compat)
    - Creating with `permissions: []` stores empty list
    - Creating with `permissions: ["*"]` stores `["*"]`
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity/application/use_cases/create_api_key.ex`
  - Pass `permissions` from `attrs` into `build_api_key_attrs/3`
  - Add `permissions: attrs[:permissions]` to the attrs map
- [x] ⏸ **REFACTOR**: Keep use case focused on orchestration

### 3.2 UpdateApiKey Use Case — Accept `permissions` Attribute

- [x] ⏸ **RED**: Update test `apps/identity/test/identity/application/use_cases/update_api_key_test.exs`
  - Tests:
    - Updating with `permissions: ["agents:read"]` updates permissions
    - Updating with `permissions: nil` does not overwrite existing permissions
    - Updating with `permissions: []` sets empty permissions
    - Updating other fields without `permissions` key does not change permissions
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity/application/use_cases/update_api_key.ex`
  - Add `:permissions` to the `Map.take(attrs, [...])` list in `execute/4`
- [x] ⏸ **REFACTOR**: Verify existing authorization (ownership check) still applies

### 3.3 Identity Facade — Add `api_key_has_permission?/2`

- [x] ⏸ **RED**: Write test in `apps/identity/test/identity_test.exs` (or update existing)
  - Tests:
    - `Identity.api_key_has_permission?/2` delegates to `ApiKeyPermissionPolicy.has_permission?/2`
    - Accepts an `%ApiKey{}` entity and a required scope string
    - Returns `true` for matching permissions
    - Returns `false` for non-matching permissions
    - Returns `true` for nil permissions (backward compat)
    - `Identity.create_api_key/2` with permissions attr works end-to-end
    - `Identity.update_api_key/3` with permissions attr works end-to-end
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity.ex`
  - Add `api_key_has_permission?/2` public function:
    ```elixir
    def api_key_has_permission?(%ApiKey{} = api_key, required_scope) do
      ApiKeyPermissionPolicy.has_permission?(api_key.permissions, required_scope)
    end
    ```
  - Add `ApiKeyPermissionPolicy` to boundary exports (other apps need to call `Identity.api_key_has_permission?/2` which is the facade function, but the policy may also be useful for presets)
- [x] ⏸ **REFACTOR**: Keep facade thin — single-line delegation

### 3.4 Boundary Configuration — Export New Policy

- [x] ⏸ **RED**: Verify `mix boundary` passes after adding the new policy module
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity.ex` boundary exports:
  - Add `Domain.Policies.ApiKeyPermissionPolicy` to exports list (for consuming apps to call `Identity.api_key_has_permission?/2` and access presets/scopes)
- [x] ⏸ **REFACTOR**: Minimal exports — only what consuming apps need

### Phase 3 Validation

- [x] ⏸ CreateApiKey tests pass: `mix test apps/identity/test/identity/application/use_cases/create_api_key_test.exs`
- [x] ⏸ UpdateApiKey tests pass: `mix test apps/identity/test/identity/application/use_cases/update_api_key_test.exs`
- [x] ⏸ Facade tests pass: `mix test apps/identity/test/identity_test.exs`
- [x] ⏸ No boundary violations: `mix boundary` (task unavailable; verified via `mix compile` and no boundary warnings)
- [x] ⏸ Full identity test suite passes: `mix test apps/identity/test/`

---

## Phase 4: Agents App — IdentityBehaviour and MCP Permission Enforcement (phoenix-tdd) ✓

> Consumer app. Tests use Mox for identity dependency injection.

### 4.1 IdentityBehaviour — Add `api_key_has_permission?/2` Callback

- [x] ⏸ **RED**: Update test `apps/agents/test/agents/application/behaviours/identity_behaviour_test.exs` (or verify callback exists)
  - Tests:
    - Behaviour defines `api_key_has_permission?/2` callback
    - Mock implementation via Mox responds correctly
- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/application/behaviours/identity_behaviour.ex`
  - Add callback:
    ```elixir
    @callback api_key_has_permission?(api_key :: ApiKey.t(), scope :: String.t()) :: boolean()
    ```
- [x] ⏸ **REFACTOR**: Keep behaviour minimal — only the contract

### 4.2 AuthenticateMcpRequest — Return API Key Entity

Currently `AuthenticateMcpRequest.execute/2` returns `{:ok, %{workspace_id: ..., user_id: ...}}`.
The MCP pipeline needs the full API key entity to check permissions. Extend the return value.

- [x] ⏸ **RED**: Update test `apps/agents/test/agents/application/use_cases/authenticate_mcp_request_test.exs`
  - Tests:
    - Successful authentication returns `api_key` entity in the result map: `{:ok, %{workspace_id: ..., user_id: ..., api_key: api_key}}`
    - Existing tests still pass with the extended return value
- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/application/use_cases/authenticate_mcp_request.ex`
  - In `resolve_workspace/2`, include `api_key` in the success map:
    ```elixir
    {:ok, %{workspace_id: workspace_id, user_id: api_key.user_id, api_key: api_key}}
    ```
- [x] ⏸ **REFACTOR**: Keep the use case focused on authentication and workspace resolution

### 4.3 MCP AuthPlug — Assign API Key to Connection

- [x] ⏸ **RED**: Update test `apps/agents/test/agents/infrastructure/mcp/auth_plug_test.exs`
  - Tests:
    - On successful auth, `conn.assigns.api_key` contains the verified API key entity
    - Existing `workspace_id` and `user_id` assigns are unchanged
- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/infrastructure/mcp/auth_plug.ex`
  - In `authenticate/3`, extract `api_key` from the `AuthenticateMcpRequest` result and assign it:
    ```elixir
    case AuthenticateMcpRequest.execute(token, auth_opts) do
      {:ok, %{workspace_id: workspace_id, user_id: user_id, api_key: api_key}} ->
        conn
        |> assign(:workspace_id, workspace_id)
        |> assign(:user_id, user_id)
        |> assign(:api_key, api_key)
    ```
- [x] ⏸ **REFACTOR**: Keep plug thin — only assigns, no business logic

### 4.4 MCP Permission Checking — Tool Execution Guard

MCP tools execute via Hermes `Server.Component`. Permission checks need to happen before
tool execution. The cleanest approach is a permission guard in `McpPipeline` that intercepts
tool call requests and checks permissions before forwarding to the Hermes transport.

However, since Hermes StreamableHTTP processes tool calls as part of the JSON-RPC message
handling, the permission check is best done at the tool component level by wrapping the
`execute/2` callback.

**Approach**: Create a reusable helper module `Agents.Infrastructure.Mcp.PermissionGuard`
that tool components call at the start of `execute/2`. The guard checks
`conn.assigns.api_key.permissions` against the tool's required scope (derived from its
registered name via `mcp:<tool_name>`).

Since Hermes tool components receive a `frame` with `assigns`, we use `frame.assigns.api_key`.

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/permission_guard_test.exs`
  - Tests:
    - `check_permission/2` with nil permissions (full access) returns `:ok`
    - `check_permission/2` with `["*"]` returns `:ok` for any tool
    - `check_permission/2` with `["mcp:knowledge.*"]` returns `:ok` for `"knowledge.search"`, `:error` for `"jarga.list_workspaces"`
    - `check_permission/2` with `["mcp:knowledge.search"]` returns `:ok` for `"knowledge.search"`, `:error` for `"knowledge.create"`
    - `check_permission/2` with `["mcp:*"]` returns `:ok` for any MCP tool
    - `check_permission/2` with `[]` returns `{:error, scope}` for any tool
    - Returns `{:error, required_scope}` with the `"mcp:<tool_name>"` scope string on denial
- [x] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/permission_guard.ex`
  - `check_permission(frame, tool_name)` — reads `frame.assigns.api_key.permissions` and checks against `"mcp:#{tool_name}"` using `Identity.api_key_has_permission?/2`
  - Returns `:ok` or `{:error, "mcp:<tool_name>"}`
  - Accepts dependency injection for the identity module via frame assigns or module attribute
- [x] ⏸ **REFACTOR**: Keep module as pure utility — no state, no side effects

### 4.5 Apply Permission Guard to Tool Components

Each tool component's `execute/2` should check permissions before proceeding. Rather than
modifying every tool, create a `__using__` macro or wrapper approach. However, to keep
this incremental, we add the check to each existing tool component.

- [x] ⏸ **RED**: Update tool component tests to verify permission denial:
  - `apps/agents/test/agents/infrastructure/mcp/tools/search_tool_test.exs` — denied with `["agents:read"]` permissions (no `mcp:knowledge.search`)
  - `apps/agents/test/agents/infrastructure/mcp/tools/create_tool_test.exs` — denied with `["mcp:knowledge.search"]` (no `mcp:knowledge.create`)
  - At least one jarga tool test for `mcp:jarga.*` wildcard matching
- [x] ⏸ **GREEN**: Update each tool component's `execute/2` to call `PermissionGuard.check_permission/2`:
  - `apps/agents/lib/agents/infrastructure/mcp/tools/search_tool.ex`
  - `apps/agents/lib/agents/infrastructure/mcp/tools/get_tool.ex`
  - `apps/agents/lib/agents/infrastructure/mcp/tools/traverse_tool.ex`
  - `apps/agents/lib/agents/infrastructure/mcp/tools/create_tool.ex`
  - `apps/agents/lib/agents/infrastructure/mcp/tools/update_tool.ex`
  - `apps/agents/lib/agents/infrastructure/mcp/tools/relate_tool.ex`
  - `apps/agents/lib/agents/infrastructure/mcp/tools/jarga/*.ex` (all 8 Jarga tools)
  - Pattern:
    ```elixir
    def execute(params, frame) do
      case PermissionGuard.check_permission(frame, "knowledge.search") do
        :ok -> # existing logic
        {:error, scope} ->
          {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"), frame}
      end
    end
    ```
- [x] ⏸ **REFACTOR**: Consider extracting a `use PermissionGuard, scope: "knowledge.search"` macro to DRY up the pattern across all 14 tools

### Phase 4 Validation

- [x] ⏸ IdentityBehaviour updated and Mox mock compiles
- [x] ⏸ AuthenticateMcpRequest tests pass: `mix test apps/agents/test/agents/application/use_cases/authenticate_mcp_request_test.exs`
- [x] ⏸ MCP AuthPlug tests pass: `mix test apps/agents/test/agents/infrastructure/mcp/auth_plug_test.exs`
- [x] ⏸ PermissionGuard tests pass: `mix test apps/agents/test/agents/infrastructure/mcp/permission_guard_test.exs`
- [x] ⏸ Tool component permission tests pass
- [x] ⏸ No boundary violations: `mix boundary` (task unavailable; verified via `mix compile` and no boundary warnings)
- [x] ⏸ Full agents test suite passes: `mix test apps/agents/test/`

---

## Phase 5: Agents API — REST Permission Enforcement Plug (phoenix-tdd) ✓

> Consumer interface app. Tests use `AgentsApi.ConnCase`.

### 5.1 ApiPermissionPlug — Scope-Based REST Enforcement

- [x] ⏸ **RED**: Write test `apps/agents_api/test/agents_api/plugs/api_permission_plug_test.exs`
  - Tests:
    - Plug with `scope: "agents:read"` allows request when `api_key.permissions` includes `"agents:read"`
    - Plug with `scope: "agents:read"` allows request when `api_key.permissions` is `nil` (backward compat)
    - Plug with `scope: "agents:read"` allows request when `api_key.permissions` is `["*"]`
    - Plug with `scope: "agents:read"` allows request when `api_key.permissions` includes `"agents:*"`
    - Plug with `scope: "agents:write"` denies request when `api_key.permissions` is `["agents:read"]`
    - Plug with `scope: "agents:write"` denies request when `api_key.permissions` is `[]`
    - Denied requests return 403 with `{"error": "insufficient_permissions", "required": "<scope>"}`
    - Plug halts connection on denial
    - Plug passes through on success (no halt)
    - Plug works with `conn.assigns.api_key` set by `ApiAuthPlug`
- [x] ⏸ **GREEN**: Implement `apps/agents_api/lib/agents_api/plugs/api_permission_plug.ex`
  - `init(opts)` — expects `scope: "agents:read"` option
  - `call(conn, opts)` — reads `conn.assigns.api_key`, calls `Identity.api_key_has_permission?/2`
  - On success: pass through (no-op)
  - On denial: halt with 403 JSON response `{"error": "insufficient_permissions", "required": scope}`
  - Pattern:
    ```elixir
    defmodule AgentsApi.Plugs.ApiPermissionPlug do
      import Plug.Conn
      @behaviour Plug

      def init(opts), do: Keyword.fetch!(opts, :scope)

      def call(conn, required_scope) do
        api_key = conn.assigns[:api_key]
        if Identity.api_key_has_permission?(api_key, required_scope) do
          conn
        else
          forbidden(conn, required_scope)
        end
      end
    end
    ```
- [x] ⏸ **REFACTOR**: Keep plug stateless and focused on permission check only

### 5.2 Router — Wire Permission Plug into Pipelines

- [x] ⏸ **RED**: Write integration tests `apps/agents_api/test/agents_api/controllers/agent_api_controller_permission_test.exs`
  - Tests:
    - `GET /api/agents` with `agents:read` permission → 200
    - `GET /api/agents` with `agents:write` only → 403
    - `POST /api/agents` with `agents:write` → 201
    - `POST /api/agents` with `agents:read` only → 403
    - `PATCH /api/agents/:id` with `agents:write` → 200
    - `DELETE /api/agents/:id` with `agents:write` → 200 (or appropriate success)
    - `POST /api/agents/:id/query` with `agents:query` → success
    - `POST /api/agents/:id/query` with `agents:read` only → 403
    - `GET /api/agents/:id/skills` with `agents:read` → 200
    - nil permissions (legacy) → all endpoints return 200
    - `["*"]` permissions → all endpoints return 200
    - `["agents:*"]` wildcard → all endpoints return 200
    - `[]` permissions → all endpoints return 403
    - Response body on 403 contains `{"error": "insufficient_permissions", "required": "<scope>"}`
- [x] ⏸ **GREEN**: Update `apps/agents_api/lib/agents_api/router.ex`
  - Add per-route or per-action permission scoping. The cleanest approach is per-route plugs:
    ```elixir
    scope "/api", AgentsApi do
      pipe_through([:api_base, :api_authenticated])

      # Read endpoints
      get("/agents", AgentApiController, :index,
        private: %{required_permission: "agents:read"})
      get("/agents/:id", AgentApiController, :show,
        private: %{required_permission: "agents:read"})
      get("/agents/:id/skills", SkillApiController, :index,
        private: %{required_permission: "agents:read"})

      # Write endpoints
      post("/agents", AgentApiController, :create,
        private: %{required_permission: "agents:write"})
      patch("/agents/:id", AgentApiController, :update,
        private: %{required_permission: "agents:write"})
      delete("/agents/:id", AgentApiController, :delete,
        private: %{required_permission: "agents:write"})

      # Query endpoints
      post("/agents/:id/query", AgentQueryController, :create,
        private: %{required_permission: "agents:query"})
    end
    ```
  - **Alternative approach** (recommended): Use a single plug in the pipeline that reads the required scope from route metadata or infers it from the HTTP method:
    - Add `plug AgentsApi.Plugs.ApiPermissionPlug` to the `:api_authenticated` pipeline
    - The plug reads `conn.private[:required_permission]` or maps method/path to scope
  - **Simplest approach**: Use controller-level plugs with `when action in [...]`:
    ```elixir
    # In AgentApiController:
    plug ApiPermissionPlug, scope: "agents:read" when action in [:index, :show]
    plug ApiPermissionPlug, scope: "agents:write" when action in [:create, :update, :delete]
    ```
- [x] ⏸ **REFACTOR**: Choose the approach that keeps router/controller changes minimal and explicit

### 5.3 API Key CRUD Endpoints — Permissions in Create/Update (P1)

The HTTP feature file includes scenarios for `POST /api/api-keys` and `PATCH /api/api-keys/:id`
accepting `permissions` in the request body. These endpoints are part of a REST API for
managing API keys.

- [x] ⏸ **RED**: Write test `apps/agents_api/test/agents_api/controllers/api_key_controller_test.exs`
  - Tests:
    - `POST /api/api-keys` with `permissions` creates API key with specified scopes
    - `POST /api/api-keys` without `permissions` creates API key with nil (full access)
    - `PATCH /api/api-keys/:id` with `permissions` updates the key's scopes
    - Response body contains the permissions array
    - Only the key's owner can update permissions
- [x] ⏸ **GREEN**: Implement `apps/agents_api/lib/agents_api/controllers/api_key_controller.ex`
  - `create/2` — calls `Identity.create_api_key/2` with permissions from params
  - `update/2` — calls `Identity.update_api_key/3` with permissions from params
  - Add JSON view for API key responses
- [x] ⏸ **GREEN**: Update `apps/agents_api/lib/agents_api/router.ex`
  - Add routes:
    ```elixir
    post("/api-keys", ApiKeyController, :create)
    patch("/api-keys/:id", ApiKeyController, :update)
    ```
  - These should be in the authenticated scope (require API key auth)
- [x] ⏸ **REFACTOR**: Keep controller thin — delegate to Identity facade

### Phase 5 Validation

- [x] ⏸ ApiPermissionPlug tests pass: `mix test apps/agents_api/test/agents_api/plugs/api_permission_plug_test.exs`
- [x] ⏸ Controller permission integration tests pass: `mix test apps/agents_api/test/agents_api/controllers/agent_api_controller_permission_test.exs`
- [x] ⏸ API key controller tests pass: `mix test apps/agents_api/test/agents_api/controllers/api_key_controller_test.exs`
- [x] ⏸ No boundary violations: `mix boundary` (task unavailable; `mix boundary` and `mix boundary.spec` are not runnable in this repo state)
- [x] ⏸ Full agents_api test suite passes: `mix test apps/agents_api/test/`

---

## Phase 6: Identity Web — LiveView Permissions UI (phoenix-tdd) ✓

> Interface layer. Tests use `IdentityWeb.ConnCase`.

### 6.1 Permission Presets and Custom Scope Selection in Create Modal

- [x] ⏸ **RED**: Update test `apps/identity/test/identity_web/live/api_keys_live_test.exs`
  - Tests:
    - Create modal shows permission presets: "Full Access", "Read Only", "Agent Operator", "Custom"
    - Clicking "Full Access" preset selects `["*"]`
    - Clicking "Read Only" preset selects the read-only scope list
    - Clicking "Agent Operator" preset selects agent operator scopes
    - Clicking "Custom" shows grouped scope checkboxes
    - Checking/unchecking individual scopes in custom mode updates selection
    - Submitting create with "Full Access" preset creates key with `["*"]`
    - Submitting create with specific scopes creates key with those scopes
    - `data-testid="api-key-name-input"` present on name field
    - `data-testid="permission-preset-full-access"` etc. present on preset buttons
    - `data-testid="scope-agents-read"` etc. present on scope checkboxes
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity_web/live/api_keys_live.ex`
  - Add `@permission_presets` module attribute pulling from `ApiKeyPermissionPolicy.presets/0`
  - Add `@all_scopes` from `ApiKeyPermissionPolicy.all_scopes/0`
  - Add assigns: `selected_preset`, `selected_permissions`, `show_custom_scopes`
  - Update `show_create_modal` event handler to initialize permission assigns
  - Add event handlers:
    - `"select_permission_preset"` — sets preset and resolves scope list
    - `"toggle_scope"` — toggles individual scope in custom mode
  - Update `create_key` handler to include `permissions` in API key creation attrs
  - Add permission preset buttons to create modal template
  - Add custom scope checkbox section (grouped by category: REST, MCP Knowledge, MCP Jarga)
  - Use `data-testid` attributes matching the browser feature file selectors
- [x] ⏸ **REFACTOR**: Extract permission preset and scope UI into a function component for reuse in edit modal

### 6.2 Permission Section in Edit Modal

- [x] ⏸ **RED**: Update test `apps/identity/test/identity_web/live/api_keys_live_test.exs`
  - Tests:
    - Edit modal shows current permissions pre-selected
    - Changing preset updates selection
    - Saving updates permissions on the key
    - Edit button has `data-testid="edit-api-key-{slugified-name}"`
    - Existing key with nil permissions shows "Full Access" preset selected and all scopes checked
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity_web/live/api_keys_live.ex`
  - Update `edit_key` handler to initialize permission assigns from existing key
  - Update `update_key` handler to include `permissions` in update attrs
  - Add permission UI to edit modal template (reuse component from 6.1)
  - Add `data-testid` attributes for edit buttons: `data-testid="edit-api-key-#{slugify(key.name)}"`
- [x] ⏸ **REFACTOR**: Ensure modal state management is clean (reset on close)

### 6.3 Permission Summary Badges on API Key List

- [x] ⏸ **RED**: Update test `apps/identity/test/identity_web/live/api_keys_live_test.exs`
  - Tests:
    - API key with nil permissions shows "Full Access" badge
    - API key with `["*"]` shows "Full Access" badge
    - API key with read-only preset shows "Read Only" badge
    - API key with custom permissions shows "Custom (N scopes)" badge
    - API key with `[]` shows "No Access" badge
    - Badge has `data-testid="api-key-permission-badge"`
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity_web/live/api_keys_live.ex`
  - Add a `permission_badge/1` function component that calls `ApiKeyPermissionPolicy.permission_summary/1`
  - Render badge in the API keys table for each key
  - Add `data-testid="api-key-permission-badge"` to badge element
  - Add "Permissions" column header to the table
- [x] ⏸ **REFACTOR**: Keep badge component pure — no side effects

### 6.4 Empty Permissions Warning

- [x] ⏸ **RED**: Update test `apps/identity/test/identity_web/live/api_keys_live_test.exs`
  - Tests:
    - Saving with empty permissions (custom mode, no scopes checked) shows warning message
    - Warning text: "Empty permissions will deny all access"
    - Warning does not prevent save (allows user to confirm)
- [x] ⏸ **GREEN**: Update `apps/identity/lib/identity_web/live/api_keys_live.ex`
  - On form submission with empty permissions, display warning flash or inline alert
  - Allow save to proceed after warning
- [x] ⏸ **REFACTOR**: Keep warning UX non-blocking

### 6.5 Token Display Enhancement — Show Permissions on New Key

- [x] ⏸ **RED**: Update test `apps/identity/test/identity_web/live/api_keys_live_test.exs`
  - Tests:
    - Token modal shows "This token is shown only once" text
    - `#api_key_token` element is visible after key creation
- [x] ⏸ **GREEN**: Verify existing token modal still works correctly with new permission flow
  - The browser feature file expects `#api_key_token` to be visible and "This token is shown only once"
  - Ensure create flow ends with token display
- [x] ⏸ **REFACTOR**: No changes needed if existing token modal already meets requirements

### Phase 6 Validation

- [x] ⏸ All LiveView tests pass: `mix test apps/identity/test/identity_web/live/api_keys_live_test.exs`
- [x] ⏸ No boundary violations: `mix boundary` (task unavailable; `mix boundary` is not runnable in this repo state and `mix boundary.spec` fails due missing compiler ETS state)
- [x] ⏸ Full identity test suite passes: `mix test apps/identity/test/`

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix precommit` passes (formatting, credo, compilation, boundary, tests)
- [ ] ⏸ `mix boundary` shows no violations
- [ ] ⏸ `mix ecto.migrate` runs successfully
- [ ] ⏸ Full umbrella test suite: `mix test` passes

---

## BDD Feature File Mapping

This section maps each BDD scenario to the implementation phases and unit tests that cover it.

### Browser Feature (9 scenarios → Phase 6)

| Scenario | Phase | Unit Test Coverage |
|----------|-------|--------------------|
| Workspace member can log in and reach API Keys settings | 6 (existing) | Auth + mount test |
| Login with invalid credentials is rejected | 6 (existing) | Auth test |
| Unauthenticated user is redirected | 6 (existing) | Auth redirect test |
| Create API key with Full Access preset | 6.1 | Create modal + preset test |
| Create API key with Read Only preset | 6.1 | Create modal + preset test |
| Create API key with Custom permissions | 6.1 | Custom scope selection test |
| Edit existing API key's permissions | 6.2 | Edit modal + update test |
| API keys list shows permission summary | 6.3 | Badge rendering test |
| Warning when saving empty permissions | 6.4 | Empty permission warning test |

### HTTP Feature (14 scenarios → Phases 3, 5)

| Scenario | Phase | Unit Test Coverage |
|----------|-------|--------------------|
| agents:read can list agents | 5.1, 5.2 | Plug allow test, controller integration |
| Without agents:read denied listing | 5.1, 5.2 | Plug deny test, 403 response |
| agents:write can create agent | 5.1, 5.2 | Plug allow test, controller integration |
| Without agents:write cannot create | 5.1, 5.2 | Plug deny test, 403 response |
| Wildcard has full access | 5.1 | Plug wildcard test |
| nil permissions has full access | 5.1 | Plug backward compat test |
| Empty permissions denied all | 5.1 | Plug empty list test |
| agents:query can query agent | 5.1, 5.2 | Plug query scope test |
| Category wildcard matches sub-scopes | 5.1 | Plug agents:* test |
| Permission returns 403 not 401 | 5.1 | Status code test |
| Unauthenticated returns 401 | 5.1 (existing) | Auth plug test |
| Invalid API key returns 401 | 5.1 (existing) | Auth plug test |
| Create API key with permissions via REST | 5.3 | ApiKeyController create test |
| Update API key permissions via REST | 5.3 | ApiKeyController update test |

### Security Feature (10 scenarios → Phases 4, 5)

| Scenario | Phase | Unit Test Coverage |
|----------|-------|--------------------|
| Prevention of unauthorized REST access | 5.1, 5.2 | Permission plug + controller tests |
| Prevention of unauthorized MCP access | 4.4, 4.5 | PermissionGuard + tool tests |
| Wildcard permissions grant appropriate access | 1.1 | Policy wildcard tests |
| Nil permissions backward compatibility | 1.1 | Policy nil test |
| Empty permissions deny all | 1.1 | Policy empty test |
| Permission check after authentication | 5.1 | Auth before permission test order |
| API key permissions cannot be escalated | 5.1, 3.2 | Ownership check in update |
| Permission changes take effect immediately | 3.2 | No caching — DB read on verify |
| Security headers on denial responses | 5.1 | 403 response headers test |
| Workspace access and permissions independent | 5.1 | Dual check in controller tests |

---

## Testing Strategy

- **Total estimated tests**: ~85-100
- **Distribution**:
  - Domain (Phase 1): ~20 tests (policy matching, entity)
  - Infrastructure (Phase 2): ~12 tests (schema, repository, migration)
  - Application (Phase 3): ~15 tests (use cases, facade)
  - Agents MCP (Phase 4): ~20 tests (behaviour, auth, guard, tools)
  - Agents API REST (Phase 5): ~20 tests (plug, controller integration, API key CRUD)
  - Identity Web (Phase 6): ~15 tests (LiveView modals, presets, badges)

- **Test pyramid**: Most tests are in the domain policy layer (fast, pure, milliseconds). Outer layers have fewer but more integration-focused tests.
- **Async**: Domain and application tests run `async: true`. Infrastructure and interface tests may run `async: false` due to database sandbox.
- **Mocking**: Agents app tests use Mox for `IdentityBehaviour` mock. Identity use case tests inject deps via opts.

---

## Appendix: Canonical Scope Registry

For reference, the full scope registry to be defined in `ApiKeyPermissionPolicy`:

**REST API scopes:**
- `agents:read` — List and show agents, skills
- `agents:write` — Create, update, delete agents
- `agents:query` — Execute agent queries

**MCP Knowledge scopes:**
- `mcp:knowledge.search`
- `mcp:knowledge.get`
- `mcp:knowledge.traverse`
- `mcp:knowledge.create`
- `mcp:knowledge.update`
- `mcp:knowledge.relate`

**MCP Jarga scopes:**
- `mcp:jarga.list_workspaces`
- `mcp:jarga.get_workspace`
- `mcp:jarga.list_projects`
- `mcp:jarga.create_project`
- `mcp:jarga.get_project`
- `mcp:jarga.list_documents`
- `mcp:jarga.create_document`
- `mcp:jarga.get_document`

**Wildcard scopes:**
- `*` — Everything
- `agents:*` — All agents REST scopes
- `mcp:*` — All MCP scopes
- `mcp:knowledge.*` — All knowledge MCP tools
- `mcp:jarga.*` — All Jarga MCP tools

**Permission presets:**
- "Full Access" → `["*"]`
- "Read Only" → `["agents:read", "mcp:knowledge.search", "mcp:knowledge.get", "mcp:knowledge.traverse", "mcp:jarga.list_workspaces", "mcp:jarga.get_workspace", "mcp:jarga.list_projects", "mcp:jarga.get_project", "mcp:jarga.list_documents", "mcp:jarga.get_document"]`
- "Agent Operator" → `["agents:read", "agents:write", "agents:query"]`
- "Custom" → User selects individual scopes
