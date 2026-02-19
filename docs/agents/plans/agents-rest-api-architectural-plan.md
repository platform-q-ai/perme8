# Feature: Agents REST API

## Overview

Create a new `agents_api` umbrella app that exposes a REST API for agent management and query execution. Follows the established `jarga_api` pattern: Phoenix Endpoint + Router + Controllers + JSON views + API key auth. The new app depends on `agents` (domain logic) and `identity` (auth).

**Ticket**: #52

## UI Strategy

- **LiveView coverage**: N/A (JSON API only, no UI)
- **TypeScript needed**: None

## Affected Boundaries

- **New app**: `agents_api` (all new code lives here)
- **Cross-context dependencies**:
  - `Agents` — facade for agent CRUD, query execution, workspace agents, skills
  - `Identity` — `verify_api_key/1`, `get_user/1` for auth
- **New context needed?**: Yes — `agents_api` as a new umbrella app (interface layer)

## Port Allocation

| Environment | Port |
|-------------|------|
| Dev         | 4008 |
| Test        | 4009 |

## Architecture Pattern

```
Client (HTTP)
    ↓
AgentsApi.Endpoint (Phoenix)
    ↓
AgentsApi.Router (pipelines: api_base → api_authenticated)
    ↓
Controllers (thin adapters)
    ↓
Agents (context facade — existing public API)
    ↓
Identity (auth verification — existing)
```

The `agents_api` app is a pure interface layer. It contains NO business logic. All agent operations delegate to the existing `Agents` context module.

## Phase 1: Scaffold Umbrella App

Create the `agents_api` umbrella app with Mix project, OTP application, Phoenix Endpoint, and configuration.

### Step 1.1: Create mix.exs

- [ ] **RED**: No test yet — this is project scaffolding
- [ ] **GREEN**: Create `apps/agents_api/mix.exs`
  - `app: :agents_api`
  - Dependencies: `phoenix`, `agents` (in_umbrella), `identity` (in_umbrella), `jason`, `bandit`, `boundary`
  - Boundary config: `externals_mode: :relaxed`, check apps relaxed for `phoenix`, `phoenix_ecto`
  - `compilers: [:boundary] ++ Mix.compilers()`
  - `elixirc_paths` for test support
- [ ] **REFACTOR**: Verify `mix deps.get` succeeds

### Step 1.2: Create AgentsApi module (Boundary + macros)

- [ ] **RED**: No test — this is a macro module
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api.ex`
  - `use Boundary, deps: [Agents, Identity], exports: [Endpoint]`
  - Define `:router` macro (Phoenix.Router, helpers: false)
  - Define `:controller` macro (Phoenix.Controller, formats: [:json])
  - Define `verified_routes` macro
  - Implement `__using__/1`

### Step 1.3: Create Endpoint

- [ ] **RED**: No test — Phoenix boilerplate
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/endpoint.ex`
  - `use Phoenix.Endpoint, otp_app: :agents_api`
  - Sandbox plug (compile-time check on `:agents_api` env, using `:identity` for sandbox config since agents_api has no repos)
  - `Plug.RequestId`, `Plug.Telemetry`, `Plug.Parsers` (JSON)
  - Plug the Router

### Step 1.4: Create OTP Application

- [ ] **RED**: No test — OTP boilerplate
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/application.ex`
  - `use Application`
  - `use Boundary, deps: [AgentsApi], exports: []`
  - Start `AgentsApi.Endpoint` as child

### Step 1.5: Create ErrorJSON

- [ ] **RED**: No test — error fallback module
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/error_json.ex`
  - `render/2` returns `%{errors: %{detail: status_message}}`

### Step 1.6: Add Configuration

- [ ] **RED**: No test — config files
- [ ] **GREEN**: Add to `config/config.exs`:
  ```elixir
  config :agents_api, AgentsApi.Endpoint,
    url: [host: "localhost"],
    adapter: Bandit.PhoenixAdapter,
    render_errors: [formats: [json: AgentsApi.ErrorJSON], layout: false],
    pubsub_server: Jarga.PubSub
  ```
- [ ] **GREEN**: Add to `config/dev.exs`:
  ```elixir
  config :agents_api, AgentsApi.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4008],
    check_origin: false,
    code_reloader: true,
    debug_errors: true,
    secret_key_base: "agents_api_dev_secret_key_base_at_least_64_bytes_long_for_security",
    watchers: []
  ```
- [ ] **GREEN**: Add to `config/test.exs`:
  ```elixir
  config :agents_api, AgentsApi.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4009],
    secret_key_base: "agents_api_test_secret_key_base_at_least_64_bytes_long_for_security"
  ```

### Step 1.7: Create Stub Router + Test Helper

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/router_test.exs`
  - Test `GET /api/health` returns 200 (smoke test that the app compiles and serves)
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/router.ex` with a health endpoint:
  ```elixir
  pipeline :api_base do
    plug :accepts, ["json"]
  end

  scope "/api", AgentsApi do
    pipe_through [:api_base]
    get "/health", HealthController, :show
  end
  ```
  Create `apps/agents_api/lib/agents_api/controllers/health_controller.ex`
  Create `apps/agents_api/test/test_helper.exs`
  Create `apps/agents_api/test/support/conn_case.ex`
  Create `apps/agents_api/.formatter.exs`
- [ ] **REFACTOR**: Run `mix test apps/agents_api` — must pass

## Phase 2: Authentication Plugs

### Step 2.1: Security Headers Plug

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/plugs/security_headers_plug_test.exs`
  - Test all 6 security headers are set on response
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/plugs/security_headers_plug.ex`
  - Same headers as `JargaApi.Plugs.SecurityHeadersPlug`: x-content-type-options, x-frame-options, referrer-policy, content-security-policy, strict-transport-security, permissions-policy
- [ ] **REFACTOR**: Verify identical to jarga_api pattern

### Step 2.2: API Auth Plug

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/plugs/api_auth_plug_test.exs`
  - Test valid Bearer token assigns `current_user` and `api_key`
  - Test missing Authorization header returns 401
  - Test invalid token returns 401
  - Test revoked API key returns 401
  - Test user not found returns 401
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/plugs/api_auth_plug.ex`
  - Extract Bearer token from Authorization header
  - Call `Identity.verify_api_key(token)`
  - Call `Identity.get_user(api_key.user_id)`
  - Assign `:api_key` and `:current_user`
  - Return 401 JSON on any failure
- [ ] **REFACTOR**: Ensure consistent error response format

### Step 2.3: Wire Pipelines in Router

- [ ] **RED**: Write integration test in router_test.exs
  - Test that authenticated endpoints return 401 without token
  - Test that authenticated endpoints pass through with valid token
- [ ] **GREEN**: Update router:
  ```elixir
  pipeline :api_base do
    plug :accepts, ["json"]
    plug AgentsApi.Plugs.SecurityHeadersPlug
  end

  pipeline :api_authenticated do
    plug AgentsApi.Plugs.ApiAuthPlug
  end
  ```
- [ ] **REFACTOR**: Run full test suite

## Phase 3: Agent CRUD Endpoints

### Step 3.1: Agent JSON View

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/agent_api_json_test.exs`
  - Test `index/1` renders list of agents
  - Test `show/1` renders single agent with all fields
  - Test `created/1` renders agent with 201 data
  - Test `error/1` renders error message
  - Test `validation_error/1` renders changeset errors
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/agent_api_json.ex`
  - `index/1` — renders `%{data: [agent, ...]}`
  - `show/1` — renders `%{data: agent}`
  - `created/1` — renders `%{data: agent}`
  - `error/1` — renders `%{error: message}`
  - `validation_error/1` — renders `%{errors: %{field: [messages]}}`
  - Agent fields: id, name, description, system_prompt, model, temperature, visibility, enabled, inserted_at, updated_at
- [ ] **REFACTOR**: Ensure all fields match Agent domain entity

### Step 3.2: List Agents (GET /api/agents)

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/agent_api_controller_test.exs` — `index` action
  - Test lists user's agents (200)
  - Test returns empty list when user has no agents (200)
  - Test requires authentication (401)
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/agent_api_controller.ex`
  - `index/2` — `Agents.list_user_agents(conn.assigns.current_user.id)`
  - Render with `agent_api_json.index`
- [ ] **REFACTOR**: Add route to router

### Step 3.3: Show Agent (GET /api/agents/:id)

- [ ] **RED**: Add test for `show` action
  - Test returns agent owned by user (200)
  - Test returns 404 for non-existent agent
  - Test returns 404 for agent owned by another user (don't leak existence)
- [ ] **GREEN**: Implement `show/2`
  - Use `Agents.list_user_agents(user_id)` then find by id, OR add a new public function if needed
  - Alternatively, use the agent repo pattern — but we should go through the `Agents` facade
  - Since `Agents` doesn't expose a `get_user_agent/2`, we need to add one or use the existing `update_user_agent` pattern of checking ownership
  - **Decision**: Add `Agents.get_user_agent(agent_id, user_id)` to the facade
- [ ] **REFACTOR**: Ensure 404 response for all not-found cases

### Step 3.4: Create Agent (POST /api/agents)

- [ ] **RED**: Add test for `create` action
  - Test creates agent with valid params (201)
  - Test returns 422 for invalid params (missing name)
  - Test auto-sets user_id from authenticated user
- [ ] **GREEN**: Implement `create/2`
  - Extract agent params from request body
  - Merge `user_id` from `conn.assigns.current_user.id`
  - Call `Agents.create_user_agent(attrs)`
  - Render 201 on success, 422 on changeset error
- [ ] **REFACTOR**: Ensure params are whitelisted (only allowed fields)

### Step 3.5: Update Agent (PATCH /api/agents/:id)

- [ ] **RED**: Add test for `update` action
  - Test updates agent with valid params (200)
  - Test returns 404 for non-existent agent
  - Test returns 404 for agent owned by another user
  - Test returns 422 for invalid params
- [ ] **GREEN**: Implement `update/2`
  - Call `Agents.update_user_agent(id, user_id, attrs)`
  - Handle `{:ok, agent}`, `{:error, :not_found}`, `{:error, changeset}`
- [ ] **REFACTOR**: Verify error responses are consistent

### Step 3.6: Delete Agent (DELETE /api/agents/:id)

- [ ] **RED**: Add test for `delete` action
  - Test deletes agent (200 with deleted agent data)
  - Test returns 404 for non-existent agent
  - Test returns 404 for agent owned by another user
- [ ] **GREEN**: Implement `delete/2`
  - Call `Agents.delete_user_agent(id, user_id)`
  - Handle `{:ok, agent}` and `{:error, :not_found}`
- [ ] **REFACTOR**: Run full test suite

### Step 3.7: Wire All CRUD Routes

- [ ] **RED**: Integration test for all routes
- [ ] **GREEN**: Update router:
  ```elixir
  scope "/api", AgentsApi do
    pipe_through [:api_base, :api_authenticated]
    resources "/agents", AgentApiController, only: [:index, :show, :create, :update, :delete]
  end
  ```
- [ ] **REFACTOR**: Run `mix compile` — no boundary warnings

## Phase 4: Add get_user_agent to Agents Facade

The `Agents` context currently doesn't expose a `get_user_agent(agent_id, user_id)` function. We need to add this for the show endpoint.

### Step 4.1: Add get_user_agent Use Case

- [ ] **RED**: Write test `apps/agents/test/agents/application/use_cases/get_user_agent_test.exs`
  - Test returns `{:ok, agent}` when agent belongs to user
  - Test returns `{:error, :not_found}` when agent doesn't exist
  - Test returns `{:error, :not_found}` when agent belongs to another user
- [ ] **GREEN**: Create `apps/agents/lib/agents/application/use_cases/get_user_agent.ex`
  - Uses `agent_repo.get_agent_for_user(user_id, agent_id)`
  - Returns `{:ok, agent}` or `{:error, :not_found}`
- [ ] **REFACTOR**: Add delegation in `Agents` facade:
  ```elixir
  defdelegate get_user_agent(agent_id, user_id), to: GetUserAgent, as: :execute
  ```
  Update boundary exports in `Agents.Application`

## Phase 5: Agent Query Endpoint

### Step 5.1: Agent Query JSON View

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/agent_query_json_test.exs`
  - Test `show/1` renders `%{data: %{response: "..."}}`
  - Test `error/1` renders error
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/agent_query_json.ex`
  - `show/1` — `%{data: %{response: response}}`
  - `error/1` — `%{error: message}`

### Step 5.2: Agent Query Controller

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/agent_query_controller_test.exs`
  - Test executes query against user's agent (200)
  - Test returns 404 for non-existent agent
  - Test returns 404 for agent owned by another user
  - Test returns 422 for missing question param
  - Test returns 500/504 on LLM timeout (with appropriate error)
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/agent_query_controller.ex`
  - `create/2` — POST /api/agents/:id/query
  - Verify agent ownership via `Agents.get_user_agent(id, user_id)`
  - Build params: `%{question: question, assigns: %{}, agent: agent}`
  - Call `Agents.agent_query(params, self())`
  - Collect streamed response synchronously (receive loop with timeout)
  - Return complete response as JSON
  - Timeout: 60 seconds (matching existing agent query timeout)
- [ ] **REFACTOR**: Ensure timeout handling returns proper error response

### Step 5.3: Wire Query Route

- [ ] **RED**: Integration test
- [ ] **GREEN**: Add to router:
  ```elixir
  post "/agents/:id/query", AgentQueryController, :create
  ```
- [ ] **REFACTOR**: Run test suite

## Phase 6: Skills Endpoint

### Step 6.1: Skill API JSON View

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/skill_api_json_test.exs`
  - Test `index/1` renders list of skills
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/skill_api_json.ex`
  - `index/1` — `%{data: [%{name: "...", description: "..."}, ...]}`

### Step 6.2: Skill API Controller

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/skill_api_controller_test.exs`
  - Test returns list of available MCP tools/skills (200)
  - Test returns 404 for non-existent agent
  - Test requires authentication (401)
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/skill_api_controller.ex`
  - `index/2` — GET /api/agents/:id/skills
  - Verify agent ownership
  - Return static list of available MCP tool names + descriptions (hardcoded for v1, since skills are system-level)
  - Skills list derived from `Agents.Infrastructure.Mcp.Server` tool registration
- [ ] **REFACTOR**: Consider extracting skill list to a function on the Agents facade

### Step 6.3: Wire Skills Route

- [ ] **RED**: Integration test
- [ ] **GREEN**: Add to router:
  ```elixir
  get "/agents/:id/skills", SkillApiController, :index
  ```
- [ ] **REFACTOR**: Run test suite

## Phase 7: OpenAPI Specification

### Step 7.1: OpenAPI Controller

- [ ] **RED**: Write test `apps/agents_api/test/agents_api/controllers/openapi_controller_test.exs`
  - Test GET /api/openapi returns 200 with JSON content-type
  - Test response contains OpenAPI version and paths
- [ ] **GREEN**: Create `apps/agents_api/lib/agents_api/controllers/openapi_controller.ex`
  - `show/2` — returns static OpenAPI 3.0 spec as JSON
  - Spec covers all endpoints, request/response schemas, auth
- [ ] **GREEN**: Create `apps/agents_api/priv/static/openapi.json`
  - OpenAPI 3.0 specification document
- [ ] **REFACTOR**: Wire route (public, unauthenticated):
  ```elixir
  scope "/api", AgentsApi do
    pipe_through [:api_base]
    get "/health", HealthController, :show
    get "/openapi", OpenApiController, :show
  end
  ```

## Phase 8: Update Documentation

### Step 8.1: Update umbrella_apps.md

- [ ] **GREEN**: Add `agents_api` row to the apps table in `docs/umbrella_apps.md`
  - App: `agents_api`, Type: Phoenix (API), Port: 4008/4009, Description: JSON REST API for agent management
- [ ] **GREEN**: Update dependency graph to include `agents_api`

### Step 8.2: Update AGENTS.md if needed

- [ ] **GREEN**: Review if any workflow hints need updating

## Phase 9: Pre-commit Validation

- [ ] Run `mix compile --warnings-as-errors` in agents_api — no warnings
- [ ] Run `mix boundary` — no violations
- [ ] Run `mix format --check-formatted`
- [ ] Run `mix credo --strict` for agents_api
- [ ] Run `mix test apps/agents_api` — all tests pass
- [ ] Run `mix test apps/agents` — existing tests still pass (regression check after Phase 4)

## File Inventory

### New Files (agents_api app)

```
apps/agents_api/
  mix.exs
  .formatter.exs
  lib/
    agents_api.ex
    agents_api/
      application.ex
      endpoint.ex
      router.ex
      error_json.ex
      plugs/
        api_auth_plug.ex
        security_headers_plug.ex
      controllers/
        health_controller.ex
        agent_api_controller.ex
        agent_api_json.ex
        agent_query_controller.ex
        agent_query_json.ex
        skill_api_controller.ex
        skill_api_json.ex
        openapi_controller.ex
  priv/
    static/
      openapi.json
  test/
    test_helper.exs
    support/
      conn_case.ex
    agents_api/
      router_test.exs
      plugs/
        api_auth_plug_test.exs
        security_headers_plug_test.exs
      controllers/
        agent_api_controller_test.exs
        agent_api_json_test.exs
        agent_query_controller_test.exs
        agent_query_json_test.exs
        skill_api_controller_test.exs
        skill_api_json_test.exs
        openapi_controller_test.exs
```

### Modified Files (existing apps)

```
config/config.exs       — add agents_api endpoint config
config/dev.exs          — add agents_api dev port config
config/test.exs         — add agents_api test port config
docs/umbrella_apps.md   — add agents_api to app table and dependency graph

apps/agents/lib/agents.ex                                        — add get_user_agent/2 delegate
apps/agents/lib/agents/application.ex                            — export GetUserAgent use case
apps/agents/lib/agents/application/use_cases/get_user_agent.ex   — NEW use case
apps/agents/test/agents/application/use_cases/get_user_agent_test.exs — NEW test
```

## Estimated Complexity

| Phase | Files | Effort |
|-------|-------|--------|
| 1. Scaffold | ~10 | Medium (boilerplate but many files) |
| 2. Auth Plugs | 4 | Small (follows jarga_api pattern exactly) |
| 3. Agent CRUD | 4 | Medium (5 actions + JSON view) |
| 4. get_user_agent | 3 | Small (thin use case) |
| 5. Query Endpoint | 4 | Medium (sync wrapper around streaming) |
| 6. Skills | 4 | Small (read-only, mostly static) |
| 7. OpenAPI | 3 | Small-Medium (spec document) |
| 8. Docs | 1 | Trivial |
| 9. Validation | 0 | Small (run commands) |
