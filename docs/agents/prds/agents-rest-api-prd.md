# PRD: Agents REST API

**Ticket:** #52 — Build agents REST API
**App:** agents_api (new umbrella app)
**Status:** Draft

## User Story

As an external system, LLM agent, or developer, I want to interact with agents programmatically via a REST API, so that I can manage agents and execute queries without the browser UI.

## Context

The agents app currently exposes functionality through:
1. **LiveView UI** — via `jarga_web` (browser-only)
2. **MCP tools** — via `Agents.Infrastructure.Mcp` (JSON-RPC for LLM tool use)

Neither channel supports general-purpose REST API access. Following the Interoperability principle and the established `jarga_api` pattern, a new `agents_api` umbrella app will provide authenticated REST endpoints for agent management and query execution.

## Scope

### In Scope

1. **Agent CRUD** — Create, list, show, update, delete agents via REST
2. **Agent query execution** — Send a question to an agent and receive a response
3. **Skills management** — List available skills/tools for an agent (read-only for v1)
4. **API key authentication** — Bearer token auth via `Identity.verify_api_key/1`
5. **Workspace-scoped access** — Agents are accessed within workspace context, respecting API key `workspace_access` scope
6. **OpenAPI documentation** — Machine-readable API spec
7. **BDD feature coverage** — HTTP adapter tests
8. **Security baseline** — Security headers, rate limiting awareness

### Out of Scope

- Streaming responses (synchronous only for v1)
- WebSocket/SSE endpoints
- Agent creation with workspace associations (manage separately)
- Knowledge MCP endpoints (already served via MCP tools)
- Billing/usage tracking

## Acceptance Criteria

### AC1: Agent CRUD endpoints
- [ ] `POST /api/agents` — Create an agent (requires `user_id` from auth)
- [ ] `GET /api/agents` — List agents for the authenticated user
- [ ] `GET /api/agents/:id` — Get agent details
- [ ] `PATCH /api/agents/:id` — Update an agent
- [ ] `DELETE /api/agents/:id` — Delete an agent
- [ ] All operations respect ownership (only owner can CRUD their agents)

### AC2: Agent query execution endpoint
- [ ] `POST /api/agents/:id/query` — Execute a query against an agent
- [ ] Request body: `{ "question": "...", "context": { ... } }`
- [ ] Response: `{ "data": { "response": "..." } }`
- [ ] Uses agent's model, temperature, and system prompt settings
- [ ] Synchronous response (blocks until LLM completes)

### AC3: Skills management endpoints
- [ ] `GET /api/agents/:id/skills` — List MCP tools/skills available to the agent
- [ ] Read-only in v1 (skills are configured at the system level)

### AC4: API key authentication via Identity
- [ ] Bearer token in `Authorization` header
- [ ] Verifies via `Identity.verify_api_key/1`
- [ ] Resolves `current_user` from API key owner
- [ ] Returns 401 for invalid/revoked/missing tokens

### AC5: Workspace-scoped access control
- [ ] Workspace context is determined from API key's `workspace_access` list
- [ ] Agent listing can be filtered by workspace: `GET /api/agents?workspace_id=...`
- [ ] Agent creation associates with a workspace when `workspace_id` is provided
- [ ] API key must have access to the workspace being referenced

### AC6: OpenAPI documentation
- [ ] OpenAPI 3.0 spec available at `GET /api/openapi`
- [ ] Documents all endpoints, request/response schemas, and authentication
- [ ] Can be generated from code or maintained as a static file

### AC7: BDD feature coverage (HTTP adapter)
- [ ] Exo-BDD HTTP features covering all endpoints
- [ ] Happy path and error scenarios

### AC8: Security baseline scan
- [ ] Security headers plug (matching `jarga_api` pattern)
- [ ] CORS headers if needed
- [ ] No sensitive data leakage in error responses

## Technical Design

### New Umbrella App: `agents_api`

Mirrors the `jarga_api` pattern:

```
apps/agents_api/
  lib/
    agents_api.ex                          # Boundary + macros (:router, :controller)
    agents_api/
      application.ex                       # OTP Application (starts Endpoint)
      endpoint.ex                          # Phoenix Endpoint
      router.ex                            # Routes with pipelines
      error_json.ex                        # Error rendering
      plugs/
        api_auth_plug.ex                   # Bearer token auth (reuse pattern from jarga_api)
        security_headers_plug.ex           # Security headers
        workspace_scope_plug.ex            # Optional: resolve workspace from params + API key
      controllers/
        agent_api_controller.ex            # Agent CRUD
        agent_api_json.ex                  # Agent JSON rendering
        agent_query_controller.ex          # Agent query execution
        agent_query_json.ex                # Query response rendering
        skill_api_controller.ex            # Skills listing
        skill_api_json.ex                  # Skills JSON rendering
        openapi_controller.ex              # OpenAPI spec endpoint
  mix.exs                                  # Dependencies: phoenix, agents, identity, jason, bandit, boundary
  test/
    test_helper.exs
    support/
    agents_api/
      controllers/
        agent_api_controller_test.exs
        agent_query_controller_test.exs
        skill_api_controller_test.exs
      plugs/
        api_auth_plug_test.exs
        security_headers_plug_test.exs
```

### Dependencies

```
agents_api → agents (domain logic)
agents_api → identity (auth, user lookup)
```

The `agents_api` app does NOT depend on `jarga`, `jarga_web`, or `jarga_api`.

### Router Design

```elixir
scope "/api", AgentsApi do
  pipe_through [:api_base, :api_authenticated]

  # Agent CRUD
  resources "/agents", AgentApiController, only: [:index, :show, :create, :update, :delete]

  # Agent query
  post "/agents/:id/query", AgentQueryController, :create

  # Skills
  get "/agents/:id/skills", SkillApiController, :index
end

scope "/api", AgentsApi do
  pipe_through [:api_base]

  # Public endpoints
  get "/openapi", OpenApiController, :show
end
```

### Port Allocation

Following the umbrella convention:
- **Dev:** 4008
- **Test:** 4009

### Authentication Flow

1. Client sends `Authorization: Bearer <token>`
2. `ApiAuthPlug` extracts token
3. `Identity.verify_api_key(token)` validates
4. Assigns `current_user` and `api_key` to conn
5. Controllers use `conn.assigns.current_user` for all operations

### JSON Response Format

Consistent with `jarga_api`:

```json
// Success
{ "data": { ... } }

// List
{ "data": [ ... ] }

// Error
{ "error": "message" }

// Validation error
{ "errors": { "field": ["message"] } }
```

### Agent Query Execution

The query endpoint delegates to `Agents.agent_query/2` but adapted for synchronous HTTP:

1. Receive question + optional context in request body
2. Call `Agents.agent_query(params, self())` (reuse existing use case)
3. Collect streamed chunks into full response
4. Return complete response as JSON

This reuses the existing `AgentQuery` use case without modification.

## Scenarios

### Scenario 1: Create an agent
```
Given I have a valid API key
When I POST /api/agents with {"name": "My Agent", "description": "Test"}
Then I receive 201 with the created agent data
And the agent is owned by the API key's user
```

### Scenario 2: List my agents
```
Given I have a valid API key
And I own 3 agents
When I GET /api/agents
Then I receive 200 with a list of 3 agents
```

### Scenario 3: Execute agent query
```
Given I have a valid API key
And I own an agent with id "agent-123"
When I POST /api/agents/agent-123/query with {"question": "What is Elixir?"}
Then I receive 200 with a response containing the agent's answer
```

### Scenario 4: Unauthorized access
```
Given I do not have a valid API key
When I GET /api/agents
Then I receive 401 with {"error": "Invalid or revoked API key"}
```

### Scenario 5: Access another user's agent
```
Given I have a valid API key
And agent "other-agent" belongs to another user
When I GET /api/agents/other-agent
Then I receive 404 (not found, not 403, to avoid leaking existence)
```

### Scenario 6: Filter agents by workspace
```
Given I have a valid API key with workspace_access ["my-workspace"]
And I have agents in "my-workspace" and "other-workspace"
When I GET /api/agents?workspace_id=my-workspace-id
Then I only see agents added to "my-workspace"
```

## Implementation Plan

See architectural plan (to be created by architect).

## Risks

1. **Agent query timeout** — LLM calls can take 30+ seconds. Need appropriate HTTP timeout and clear error handling.
2. **Port conflict** — New port allocation (4008/4009) must not conflict with existing apps.
3. **Boundary violations** — New app must stay within its boundary; no reaching into jarga or jarga_web.

## References

- `apps/jarga_api/` — Reference implementation for REST API pattern
- `apps/agents/lib/agents.ex` — Public API facade for agents domain
- `apps/identity/` — API key authentication system
