# Agents

Standalone umbrella app for agent definitions, LLM orchestration, the Knowledge MCP tool endpoint, and threaded coding sessions.

## Architecture

The agents app follows Clean Architecture with three boundary-enforced layers:

```
Agents.Domain          -- Pure entities, policies, value objects (no I/O)
Agents.Application     -- Use cases, behaviours, gateway interfaces
Agents.Infrastructure  -- MCP server, tools, ERM gateway, auth plug
```

The app contains three bounded contexts:

| Context | Facade | Purpose |
|---------|--------|---------|
| Agent CRUD | `Agents` | Agent definitions, cloning, workspace assignment, LLM client |
| Knowledge MCP | `Agents` | MCP endpoint exposing knowledge graph tools to LLM agents |
| Sessions | `Agents.Sessions` | Threaded coding sessions backed by ephemeral opencode containers |

### Agent CRUD

Agent definitions (CRUD, cloning, workspace assignment, LLM client, query execution) were extracted from `jarga` into this standalone app. The `Agents` facade exposes all public API functions. `jarga_web` LiveViews and `jarga_api` controllers call the facade directly.

### Knowledge MCP

A standalone [MCP](https://modelcontextprotocol.io/) endpoint exposes 6 knowledge graph tools via JSON-RPC 2.0 over HTTP. The tools allow LLM agents to create, search, update, relate, traverse, and retrieve knowledge entries stored in the Entity Relationship Manager (ERM).

| Tool | Description |
|------|-------------|
| `knowledge.create` | Create a knowledge entry with title, body, category, tags |
| `knowledge.get` | Retrieve an entry by ID |
| `knowledge.search` | Search by keyword, category, or tags |
| `knowledge.update` | Update an entry's fields |
| `knowledge.relate` | Create a relationship between two entries |
| `knowledge.traverse` | Walk the knowledge graph from an entry |

**Protocol:** MCP (JSON-RPC 2.0) via Hermes StreamableHTTP transport
**Auth:** Bearer token (Identity API keys) validated by `AuthPlug`
**Port:** 4007 (test)

### Key Modules

| Module | Purpose |
|--------|---------|
| `Agents` | Public facade for agent CRUD and knowledge operations |
| `Agents.OTPApp` | OTP supervisor -- starts Bandit HTTP server for MCP |
| `Agents.Infrastructure.Mcp.Router` | Plug router with `/health` and MCP pipeline |
| `Agents.Infrastructure.Mcp.McpPipeline` | Chains AuthPlug with Hermes StreamableHTTP.Plug |
| `Agents.Infrastructure.Mcp.AuthPlug` | Validates Bearer tokens via Identity API keys |
| `Agents.Infrastructure.Mcp.Server` | Hermes MCP server with tool registration |
| `Agents.Infrastructure.Gateways.ErmGateway` | Adapter to EntityRelationshipManager facade |
| `Agents.Domain.Entities.KnowledgeEntry` | Pure domain struct for knowledge entries |
| `Agents.Domain.Policies.KnowledgeValidationPolicy` | Category, tag, and relationship validation |
| `Agents.Domain.Policies.SearchPolicy` | Search criteria validation and normalization |

### Sessions

Threaded coding sessions that spawn ephemeral Docker containers running [opencode](https://opencode.ai/), stream real-time SSE events to the browser via PubSub, and clean up on completion, failure, cancellation, or timeout.

**How it works:**
1. User submits an instruction via the Sessions LiveView
2. `CreateTask` persists the task, then starts a `TaskRunner` GenServer via DynamicSupervisor
3. TaskRunner boots a Docker container (`perme8/opencode`), waits for health, creates an opencode session, and sends the prompt
4. SSE events stream back through PubSub to the LiveView in real-time
5. On completion/failure/cancel/timeout, the container is stopped and removed

**Layers:**

```
Agents.Sessions.Domain          -- Task entity, TaskPolicy (status transitions, cancellability)
Agents.Sessions.Application     -- CreateTask, CancelTask, GetTask, ListTasks use cases
Agents.Sessions.Infrastructure  -- TaskRunner, DockerAdapter, OpencodeClient, TaskRepository
```

**Public API** (`Agents.Sessions` facade):

```elixir
Agents.Sessions.create_task(attrs)              # Create and start a coding task
Agents.Sessions.cancel_task(task_id, user_id)   # Cancel a running task
Agents.Sessions.get_task(task_id, user_id)       # Get a task by ID (ownership-checked)
Agents.Sessions.list_tasks(user_id)              # List all tasks for a user
```

All functions accept an optional trailing `opts` keyword list for dependency injection.

**Key Modules:**

| Module | Purpose |
|--------|---------|
| `Agents.Sessions` | Public facade for session operations |
| `Agents.Sessions.Domain.Entities.Task` | Pure value object: instruction, status, container_id, error |
| `Agents.Sessions.Domain.Policies.TaskPolicy` | Status validation, cancellability, state transitions |
| `Agents.Sessions.Application.UseCases.CreateTask` | Validates, persists, starts TaskRunner |
| `Agents.Sessions.Application.UseCases.CancelTask` | Ownership check + cancellation via Registry |
| `Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour` | Port for task persistence |
| `Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour` | Port for opencode HTTP/SSE |
| `Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour` | Port for container lifecycle |
| `Agents.Sessions.Application.SessionsConfig` | Configuration: image, max concurrency, timeout |
| `Agents.Sessions.Infrastructure.TaskRunner` | GenServer managing full task lifecycle |
| `Agents.Sessions.Infrastructure.TaskRunnerSupervisor` | DynamicSupervisor for TaskRunner processes |
| `Agents.Sessions.Infrastructure.Adapters.DockerAdapter` | Docker CLI adapter (start, stop, inspect) |
| `Agents.Sessions.Infrastructure.Clients.OpencodeClient` | HTTP/SSE client for opencode API |
| `Agents.Sessions.Infrastructure.Repositories.TaskRepository` | Ecto-backed task persistence |
| `Agents.Sessions.Infrastructure.Schemas.TaskSchema` | Ecto schema for `sessions_tasks` table |
| `Agents.Sessions.Infrastructure.Queries.TaskQueries` | Composable Ecto query functions |

**Container Security:**
- Ports bound to `127.0.0.1` only (no external access)
- `--cap-drop=ALL` (no Linux capabilities)
- `--memory=512m`, `--cpus=1` (resource limits)
- Non-root `appuser` inside the container
- Auto-cleanup on task completion/failure

**LiveView:** `JargaWeb.AppLive.Sessions.Index` -- instruction form, real-time event log, cancel button, task history with status badges.

**Migration:** `sessions_tasks` table in `jarga` repo with indexes on `user_id`, `status`, and composite `[:user_id, :status]`.

**Docker image:** `infra/opencode/Dockerfile` -- based on `oven/bun`, installs `opencode-ai@latest`, runs as non-root `appuser`, exposes port 4096.

## Domain Events

Agent use cases emit structured domain events via the `Perme8.Events.EventBus`:

| Event | Aggregate | Emitted By |
|-------|-----------|------------|
| `AgentCreated` | `agent` | Agent creation flow |
| `AgentUpdated` | `agent` | `UpdateUserAgent` use case |
| `AgentDeleted` | `agent` | `DeleteUserAgent` use case |
| `AgentAddedToWorkspace` | `agent` | `SyncAgentWorkspaces` use case |
| `AgentRemovedFromWorkspace` | `agent` | `SyncAgentWorkspaces` use case |

All use cases inject `event_bus` via `opts[:event_bus]` for testability.

## Dependencies

- **`identity`** (in_umbrella) -- authentication, workspace resolution, API keys
- **`jarga`** (in_umbrella) -- Ecto repo for sessions task persistence
- **`entity_relationship_manager`** (in_umbrella) -- knowledge graph storage
- Hermes MCP -- MCP protocol library (JSON-RPC 2.0)
- Bandit -- HTTP server for MCP endpoint
- Boundary -- compile-time boundary enforcement
- Req -- HTTP client (Sessions opencode communication)

## Testing

```bash
# Run all agents unit tests (~400 tests)
mix test apps/agents/test

# Run only sessions tests
mix test apps/agents/test/agents/sessions

# Run exo-bdd HTTP integration tests (26 scenarios)
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts --adapter http

# Run exo-bdd security tests (16 scenarios, requires ZAP)
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts --adapter security

# Run with tag filter
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts \
  --adapter http --tags "@smoke"
```

### Test Coverage

**Agent CRUD + Knowledge MCP:**

| Layer | Tests | Notes |
|-------|-------|-------|
| Domain entities | 25 | Pure struct tests, validation |
| Domain policies | 28 | Category, tag, relationship, search validation |
| Application use cases | 120 | CRUD, bootstrap, create, search, traverse, relate, update, auth |
| Infrastructure | 124 | MCP tools, auth plug, router, server, ERM gateway |
| Exo-BDD HTTP | 26 scenarios | End-to-end MCP protocol tests |
| Exo-BDD Security | 16 scenarios | ZAP security scans (SQLi, XSS, headers, baseline) |

**Sessions:**

| Layer | Tests | Notes |
|-------|-------|-------|
| Domain entities | Task struct | `new/1`, `from_schema/1`, valid statuses |
| Domain policies | TaskPolicy | Status validation, cancellability, transitions |
| Application use cases | CreateTask, CancelTask, GetTask, ListTasks | Mocked repos and runners |
| Application config | SessionsConfig | Configuration accessors |
| Infrastructure schemas | TaskSchema | Changeset validations |
| Infrastructure queries | TaskQueries | Composable Ecto queries |
| Infrastructure repos | TaskRepository | Ecto persistence (database tests) |
| Infrastructure adapters | DockerAdapter | Docker CLI with injected System.cmd |
| Infrastructure clients | OpencodeClient | HTTP/SSE with injected http function |
| Infrastructure runner | TaskRunner (3 files) | Init, events, completion/failure/cancel/timeout |
| Facade | Agents.Sessions | Integration tests through public API |

## Configuration

**MCP** -- configured in `config/test.exs`:

```elixir
config :agents, :mcp_transport, :http
config :agents, :mcp_http_port, 4007
```

**Sessions** -- configured in `config/config.exs`:

```elixir
config :agents, :sessions,
  opencode_image: "perme8/opencode:latest",
  max_concurrent_tasks: 3,
  task_timeout_ms: 300_000,
  health_check_retries: 30,
  health_check_interval_ms: 1_000
```

The exo-bdd config is at `apps/agents/test/exo-bdd-agents.config.ts`.
