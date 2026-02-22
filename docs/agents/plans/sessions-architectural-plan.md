# Feature: Threaded Opencode Sessions for Perme8 Inside Jarga

**Ticket**: #57
**Status**: In Progress (Phase 12+)
**Created**: 2026-02-20
**Updated**: 2026-02-22 — Persistent containers, session resume, output caching

---

## Overview

Build a new `Agents.Sessions` bounded context within the `agents` app that enables developers to run agentic coding sessions from within Jarga. Each task runs in a Docker container running `opencode serve`, with the Elixir backend communicating via the opencode HTTP API and SSE event stream. Events are streamed in real-time via PubSub (in-memory only, not persisted). A dedicated LiveView page in `jarga_web` provides the user interface.

### Container Lifecycle (Revised 2026-02-22)

Containers are **task-scoped, not prompt-scoped**. They persist across multiple instructions until the user explicitly deletes the session (or, in future, until the associated PR is merged/closed via webhook).

```
Container started → opencode runs → prompt completes (idle)
  → container STOPPED (docker stop) — preserves filesystem, opencode state
  → user views historical output → container restarted → messages fetched via API → stopped
  → user sends follow-up instruction → container restarted → new prompt in same session → stopped
  → user deletes session → container REMOVED (docker rm -f) + DB row deleted
```

This enables:
- **Resumability**: follow-up instructions run in the same container with full git state and conversation history
- **Historical output**: fetch conversation from the opencode API by restarting the container
- **Output caching**: assistant output is cached in a DB `output` column to avoid restarting containers for viewing
- **Explicit cleanup**: containers are only destroyed on user delete (manual) or PR merge (future webhook)

## UI Strategy

- **LiveView coverage**: 95% -- all rendering, form submission, task history, and real-time event display
- **TypeScript needed**: One JS hook (`SessionLogHook`) for auto-scrolling the event log container. This is a browser API concern (scrollTop management) that LiveView cannot handle natively. Follows existing class-based hook pattern (e.g., `ChatPanelHook`, `FlashHook`).

## Affected Boundaries

- **Primary context**: `Agents.Sessions` (new bounded context within `agents` app)
- **Dependencies**: `Identity` (for user_id foreign key), `Identity.Repo` (shared Ecto repo)
- **Exported entities**: `Agents.Sessions.Domain.Entities.Task` (domain entity for cross-boundary use)
- **New context needed?**: Yes -- Sessions is a distinct bounded context from the existing Agents context. They share the same umbrella app but have separate domain/application/infrastructure layers.
- **Interface layer**: `jarga_web` -- new LiveView page at `/app/sessions`

## Configuration

Add to `config/config.exs`:
```elixir
config :agents, :sessions,
  image: "perme8-opencode",
  max_concurrent_tasks: 1,
  task_timeout_ms: 600_000,
  health_check_interval_ms: 1_000,
  health_check_max_retries: 30

config :agents, :sessions_env,
  ANTHROPIC_API_KEY: System.get_env("ANTHROPIC_API_KEY")
```

Add to `config/test.exs`:
```elixir
config :agents, :sessions,
  image: "perme8-opencode",
  max_concurrent_tasks: 1,
  task_timeout_ms: 10_000,
  health_check_interval_ms: 100,
  health_check_max_retries: 5
```

## Mox Mock Definitions

Add to `apps/agents/test/test_helper.exs`:
```elixir
# Sessions mocks
Mox.defmock(Agents.Mocks.ContainerProviderMock,
  for: Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour
)

Mox.defmock(Agents.Mocks.OpencodeClientMock,
  for: Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour
)

Mox.defmock(Agents.Mocks.TaskRepositoryMock,
  for: Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour
)
```

---

## Phase 1: Domain -- Task Entity, Domain Events ✓

**Goal**: Pure domain layer with zero infrastructure dependencies.

### 1.1 Task Domain Entity

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/task_test.exs`
  - Test `Task.new/1` creates a struct with all fields and defaults
  - Test `Task.new/1` sets default `status: "pending"` when not provided
  - Test `Task.from_schema/1` converts an infrastructure schema to domain entity
  - Test all fields are mapped: `id`, `instruction`, `status`, `container_id`, `container_port`, `session_id`, `user_id`, `error`, `started_at`, `completed_at`, `inserted_at`, `updated_at`
  - Test `Task.valid_statuses/0` returns `["pending", "starting", "running", "completed", "failed", "cancelled"]`
  - Use `ExUnit.Case, async: true` (pure domain, no DB)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/task.ex`
  - Pure struct with `defstruct`
  - `@type t :: %__MODULE__{...}` typespec
  - `new/1` function
  - `from_schema/1` function
  - `valid_statuses/0` function
  - Follow `Agents.Domain.Entities.Agent` pattern exactly
- [ ] **REFACTOR**: Clean up, ensure no Ecto dependencies

### 1.2 TaskCreated Domain Event

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/task_created_test.exs`
  - Test `TaskCreated.new/1` creates event struct with required fields
  - Test required fields: `task_id`, `user_id`, `instruction`
  - Test base fields are populated: `event_id`, `event_type`, `occurred_at`
  - Use `ExUnit.Case, async: true`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/task_created.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "task", fields: [task_id: nil, user_id: nil, instruction: nil], required: [:task_id, :user_id, :instruction]`
  - Follow `Agents.Domain.Events.AgentCreated` pattern exactly
- [ ] **REFACTOR**: Clean up

### 1.3 TaskStatusChanged Domain Event

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/task_status_changed_test.exs`
  - Test `TaskStatusChanged.new/1` creates event struct with required fields
  - Test required fields: `task_id`, `old_status`, `new_status`
  - Test base fields are populated
  - Use `ExUnit.Case, async: true`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/task_status_changed.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "task", fields: [task_id: nil, old_status: nil, new_status: nil], required: [:task_id, :old_status, :new_status]`
- [ ] **REFACTOR**: Clean up

### 1.4 TaskPolicy (Domain Policy)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/task_policy_test.exs`
  - Test `valid_status?/1` returns true for all valid statuses
  - Test `valid_status?/1` returns false for invalid statuses
  - Test `can_cancel?/1` returns true for `"pending"`, `"starting"`, `"running"`
  - Test `can_cancel?/1` returns false for `"completed"`, `"failed"`, `"cancelled"`
  - Test `valid_status_transition?/2` for allowed transitions: `pending->starting`, `starting->running`, `running->completed`, `running->failed`, etc.
  - Test `valid_status_transition?/2` returns false for invalid transitions (e.g., `completed->running`)
  - Use `ExUnit.Case, async: true` (pure functions, no I/O)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/task_policy.ex`
  - Pure functions only, no dependencies
- [ ] **REFACTOR**: Clean up

### 1.5 Sessions Domain Boundary

- [ ] Create `apps/agents/lib/agents/sessions/domain.ex`:
  ```elixir
  defmodule Agents.Sessions.Domain do
    use Boundary,
      top_level?: true,
      deps: [],
      exports: [
        Entities.Task,
        Events.TaskCreated,
        Events.TaskStatusChanged,
        Policies.TaskPolicy
      ]
  end
  ```

### Phase 1 Validation

- [ ] All domain tests pass with `mix test apps/agents/test/agents/sessions/domain/ --trace` (milliseconds, no I/O)
- [ ] No boundary violations (`mix compile`)

---

## Phase 2: Infrastructure -- Task Schema, Migration, Repository, Queries ✓

**Goal**: Database persistence layer for tasks.

### 2.1 Database Migration

- [ ] Create migration `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_sessions_tasks.exs`:
  ```elixir
  defmodule Jarga.Repo.Migrations.CreateSessionsTasks do
    use Ecto.Migration

    def change do
      create table(:sessions_tasks, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :instruction, :text, null: false
        add :status, :string, null: false, default: "pending"
        add :container_id, :string
        add :container_port, :integer
        add :session_id, :string
        add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
        add :error, :text
        add :started_at, :utc_datetime_usec
        add :completed_at, :utc_datetime_usec

        timestamps(type: :utc_datetime_usec)
      end

      create index(:sessions_tasks, [:user_id])
      create index(:sessions_tasks, [:status])
      create index(:sessions_tasks, [:user_id, :inserted_at])
    end
  end
  ```
- [ ] Run `mix ecto.migrate` to verify

### 2.2 TaskSchema (Infrastructure Schema)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_test.exs`
  - Test valid changeset with all required fields (`instruction`, `user_id`)
  - Test changeset requires `instruction` (not blank)
  - Test changeset requires `user_id`
  - Test changeset validates `status` is one of valid statuses
  - Test changeset defaults `status` to `"pending"`
  - Test changeset accepts optional fields: `container_id`, `container_port`, `session_id`, `error`, `started_at`, `completed_at`
  - Test `status_changeset/2` only allows updating `status`, `container_id`, `container_port`, `session_id`, `error`, `started_at`, `completed_at`
  - Use `Agents.DataCase` (needs DB for changeset testing)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex`
  - `use Ecto.Schema`, `import Ecto.Changeset`
  - `@primary_key {:id, Ecto.UUID, autogenerate: true}`
  - `@foreign_key_type Ecto.UUID`
  - Schema `"sessions_tasks"` with all fields from domain model
  - `timestamps(type: :utc_datetime_usec)` -- NOTE: ticket specifies usec
  - `changeset/2` for creation
  - `status_changeset/2` for status updates (only mutable fields)
  - Follow `Agents.Infrastructure.Schemas.AgentSchema` pattern
- [ ] **REFACTOR**: Clean up

### 2.3 TaskQueries (Infrastructure Queries)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs`
  - Test `base/0` returns a queryable
  - Test `for_user/2` filters by user_id
  - Test `by_status/2` filters by status
  - Test `by_id/2` filters by id
  - Test `recent_first/1` orders by `inserted_at` desc
  - Test `running_count_for_user/1` counts tasks with status in `["pending", "starting", "running"]`
  - Use `Agents.DataCase` (needs DB for query testing)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex`
  - `import Ecto.Query, warn: false`
  - `base/0`, `for_user/2`, `by_status/2`, `by_id/2`, `recent_first/1`, `running_count_for_user/1`
  - All return queryables (not results)
  - Follow `Agents.Infrastructure.Queries.AgentQueries` pattern
- [ ] **REFACTOR**: Clean up

### 2.4 TaskRepository (Infrastructure Repository)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs`
  - Test `create_task/1` inserts task with valid attrs, returns `{:ok, schema}`
  - Test `create_task/1` returns `{:error, changeset}` for invalid attrs
  - Test `get_task/1` returns task by id or nil
  - Test `get_task_for_user/2` returns task only if owned by user
  - Test `update_task_status/2` updates status and related fields
  - Test `list_tasks_for_user/2` returns tasks ordered by most recent first
  - Test `running_task_count_for_user/1` returns count of active tasks
  - Use `Agents.DataCase` (needs DB)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex`
  - `@behaviour Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour`
  - `alias Identity.Repo, as: Repo`
  - `create_task/1`, `get_task/1`, `get_task_for_user/2`, `update_task_status/2`, `list_tasks_for_user/2`, `running_task_count_for_user/1`
  - Follow `Agents.Infrastructure.Repositories.AgentRepository` pattern
- [ ] **REFACTOR**: Clean up

### 2.5 Sessions Infrastructure Boundary

- [ ] Create `apps/agents/lib/agents/sessions/infrastructure.ex`:
  ```elixir
  defmodule Agents.Sessions.Infrastructure do
    use Boundary,
      top_level?: true,
      deps: [
        Agents.Sessions.Domain,
        Agents.Sessions.Application,
        Identity.Repo
      ],
      exports: [
        Schemas.TaskSchema,
        Repositories.TaskRepository,
        Queries.TaskQueries
      ]
  end
  ```

### 2.6 Test Fixtures

- [ ] Create `apps/agents/test/support/fixtures/sessions_fixtures.ex`:
  ```elixir
  defmodule Agents.SessionsFixtures do
    use Boundary, top_level?: true, deps: [Agents.Sessions.Infrastructure, Agents.Test.AccountsFixtures], exports: []

    import Agents.Test.AccountsFixtures

    alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
    alias Identity.Repo

    def task_fixture(attrs \\ %{}) do
      user_id = attrs[:user_id] || user_fixture().id

      {:ok, task} =
        %TaskSchema{}
        |> TaskSchema.changeset(%{
          user_id: user_id,
          instruction: attrs[:instruction] || "Write tests for the login flow",
          status: attrs[:status] || "pending"
        })
        |> Repo.insert()

      task
    end
  end
  ```

### Phase 2 Validation

- [ ] All infrastructure tests pass
- [ ] Migration runs successfully (`mix ecto.migrate`)
- [ ] No boundary violations (`mix compile`)

---

## Phase 3: Application -- Behaviours (ContainerProvider, OpencodeClient, TaskRepository), GatewayConfig ✓

**Goal**: Define contracts (behaviours) for all infrastructure dependencies.

### 3.1 TaskRepositoryBehaviour

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/behaviours/task_repository_behaviour_test.exs`
  - Test that `Agents.Sessions.Infrastructure.Repositories.TaskRepository` implements the behaviour
  - Compile-time check: verify module has all required callbacks
  - Use `ExUnit.Case, async: true`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex`
  - Callbacks: `create_task/1`, `get_task/1`, `get_task_for_user/2`, `update_task_status/2`, `list_tasks_for_user/2`, `running_task_count_for_user/1`
  - Follow `Agents.Application.Behaviours.AgentRepositoryBehaviour` pattern
- [ ] **REFACTOR**: Clean up

### 3.2 ContainerProviderBehaviour

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/behaviours/container_provider_behaviour_test.exs`
  - Test that the behaviour module defines all expected callbacks
  - Use `ExUnit.Case, async: true`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/behaviours/container_provider_behaviour.ex`
  - Callbacks:
    ```elixir
    @callback start(image :: String.t(), opts :: keyword()) ::
      {:ok, %{container_id: String.t(), port: integer()}} | {:error, term()}
    @callback stop(container_id :: String.t()) :: :ok | {:error, term()}
    @callback status(container_id :: String.t()) ::
      {:ok, :running | :stopped | :not_found} | {:error, term()}
    ```
- [ ] **REFACTOR**: Clean up

### 3.3 OpencodeClientBehaviour

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/behaviours/opencode_client_behaviour_test.exs`
  - Test that the behaviour module defines all expected callbacks
  - Use `ExUnit.Case, async: true`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/behaviours/opencode_client_behaviour.ex`
  - Callbacks:
    ```elixir
    @callback health(base_url :: String.t()) :: :ok | {:error, term()}
    @callback create_session(base_url :: String.t(), opts :: keyword()) ::
      {:ok, map()} | {:error, term()}
    @callback send_prompt_async(base_url :: String.t(), session_id :: String.t(), parts :: list(), opts :: keyword()) ::
      :ok | {:error, term()}
    @callback abort_session(base_url :: String.t(), session_id :: String.t()) ::
      {:ok, boolean()} | {:error, term()}
    @callback subscribe_events(base_url :: String.t(), caller_pid :: pid()) ::
      {:ok, pid()} | {:error, term()}
    ```
- [ ] **REFACTOR**: Clean up

### 3.4 SessionsConfig (Application Config Module)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/sessions_config_test.exs`
  - Test `image/0` returns configured image name
  - Test `max_concurrent_tasks/0` returns configured limit
  - Test `task_timeout_ms/0` returns configured timeout
  - Test `health_check_interval_ms/0` returns configured interval
  - Test `health_check_max_retries/0` returns configured retries
  - Test `container_env/0` returns env var map from config
  - Use `ExUnit.Case, async: true`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/sessions_config.ex`
  - Reads from `Application.get_env(:agents, :sessions, [])` and `:sessions_env`
  - Provides accessor functions with defaults
- [ ] **REFACTOR**: Clean up

### 3.5 Sessions Application Boundary

- [ ] Create `apps/agents/lib/agents/sessions/application.ex`:
  ```elixir
  defmodule Agents.Sessions.Application do
    use Boundary,
      top_level?: true,
      deps: [Agents.Sessions.Domain],
      exports: [
        Behaviours.ContainerProviderBehaviour,
        Behaviours.OpencodeClientBehaviour,
        Behaviours.TaskRepositoryBehaviour,
        UseCases.CreateTask,
        UseCases.CancelTask,
        UseCases.GetTask,
        UseCases.ListTasks,
        SessionsConfig
      ]
  end
  ```

### Phase 3 Validation

- [ ] All behaviour tests pass
- [ ] No boundary violations (`mix compile`)

---

## Phase 4: Application -- Use Cases (CreateTask, CancelTask, GetTask, ListTasks) ✓

**Goal**: Business operation orchestration with mocked dependencies.

### 4.1 CreateTask Use Case

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs`
  - Test creates task when instruction is valid and no tasks running
  - Test returns `{:error, :instruction_required}` when instruction is blank/nil
  - Test returns `{:error, :concurrent_limit_reached}` when user already has a running task
  - Test emits `TaskCreated` event after successful creation
  - Test starts `TaskRunner` GenServer (via injected `task_runner_starter`)
  - Test returns `{:ok, task}` with domain entity
  - Mock dependencies: `task_repo`, `event_bus`, `task_runner_starter`
  - Use `Agents.DataCase` with Mox (for repository mock)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`
  - `execute(attrs, opts \\ [])` pattern
  - DI: `task_repo`, `event_bus`, `task_runner_starter`
  - Validate instruction present
  - Check concurrent limit via `task_repo.running_task_count_for_user/1`
  - Create task via `task_repo.create_task/1`
  - Emit `TaskCreated` event
  - Start TaskRunner via injected starter
  - Follow `Jarga.Chat.Application.UseCases.CreateSession` pattern
- [ ] **REFACTOR**: Clean up

### 4.2 CancelTask Use Case

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/cancel_task_test.exs`
  - Test cancels a running task (sends cancel message to TaskRunner)
  - Test returns `{:error, :not_found}` when task doesn't exist
  - Test returns `{:error, :not_found}` when task belongs to another user
  - Test returns `{:error, :not_cancellable}` when task is already completed/failed/cancelled
  - Use Mox for `task_repo`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/cancel_task.ex`
  - `execute(task_id, user_id, opts \\ [])`
  - DI: `task_repo`
  - Lookup task with ownership check
  - Validate cancellable status via `TaskPolicy.can_cancel?/1`
  - Send cancel message to TaskRunner via Registry lookup
- [ ] **REFACTOR**: Clean up

### 4.3 GetTask Use Case

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/get_task_test.exs`
  - Test returns `{:ok, task}` when task exists and owned by user
  - Test returns `{:error, :not_found}` when task doesn't exist
  - Test returns `{:error, :not_found}` when task belongs to another user
  - Use Mox for `task_repo`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/get_task.ex`
  - `execute(task_id, user_id, opts \\ [])`
  - DI: `task_repo`
  - Lookup task with ownership check via `task_repo.get_task_for_user/2`
  - Return `Task` domain entity via `Task.from_schema/1`
- [ ] **REFACTOR**: Clean up

### 4.4 ListTasks Use Case

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/list_tasks_test.exs`
  - Test returns list of tasks for user, most recent first
  - Test returns empty list when user has no tasks
  - Test converts schema results to domain entities
  - Use Mox for `task_repo`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/list_tasks.ex`
  - `execute(user_id, opts \\ [])`
  - DI: `task_repo`
  - List tasks via `task_repo.list_tasks_for_user/2`
  - Map results through `Task.from_schema/1`
- [ ] **REFACTOR**: Clean up

### Phase 4 Validation

- [ ] All use case tests pass (with mocks)
- [ ] No boundary violations (`mix compile`)

---

## Phase 5: Infrastructure -- Docker Adapter ✓

**Goal**: ContainerProvider implementation using Docker CLI.

### 5.1 DockerAdapter

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/adapters/docker_adapter_test.exs`
  - Test `start/2` returns `{:ok, %{container_id: _, port: _}}` on success
  - Test `start/2` passes env vars from config to `docker run`
  - Test `start/2` returns `{:error, reason}` when docker run fails
  - Test `stop/1` returns `:ok` on success
  - Test `stop/1` returns `{:error, reason}` when container not found
  - Test `status/1` returns `{:ok, :running}` for running container
  - Test `status/1` returns `{:ok, :stopped}` for stopped container
  - Test `status/1` returns `{:ok, :not_found}` for non-existent container
  - Use `Agents.DataCase` with `Bypass` or mock `System.cmd/3`
  - **Note**: These tests should mock `System.cmd/3` via dependency injection to avoid requiring Docker in CI
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/adapters/docker_adapter.ex`
  - `@behaviour Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour`
  - `start/2`: Runs `docker run -d -p 0:4096 --rm --env KEY=VAL <image>`, then `docker port <id> 4096` to discover mapped port
  - `stop/1`: Runs `docker stop <id>`
  - `status/1`: Runs `docker inspect --format '{{.State.Status}}' <id>`
  - DI for `System.cmd/3` via opts (`:system_cmd` -- defaults to `&System.cmd/3`)
  - Reads env vars from `SessionsConfig.container_env/0`
- [ ] **REFACTOR**: Clean up, extract port parsing logic

### Phase 5 Validation

- [ ] Docker adapter tests pass
- [ ] No boundary violations

---

## Phase 6: Infrastructure -- Opencode Client (HTTP + SSE) ✓

**Goal**: HTTP/SSE client for communicating with the opencode server.

### 6.1 OpencodeClient (Req-based HTTP)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/clients/opencode_client_test.exs`
  - Test `health/1` returns `:ok` when health endpoint responds 200
  - Test `health/1` returns `{:error, :unhealthy}` when endpoint fails
  - Test `create_session/2` returns `{:ok, %{id: session_id, ...}}` on 200
  - Test `create_session/2` returns `{:error, reason}` on failure
  - Test `send_prompt_async/4` returns `:ok` on 200
  - Test `send_prompt_async/4` returns `{:error, reason}` on failure
  - Test `abort_session/2` returns `{:ok, true}` on successful abort
  - Test `subscribe_events/2` spawns process that forwards SSE events as messages
  - Use `Bypass` for HTTP testing (already a dependency)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/clients/opencode_client.ex`
  - `@behaviour Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour`
  - Uses `Req` library for all HTTP calls
  - `health/1`: `GET <base_url>/global/health`
  - `create_session/2`: `POST <base_url>/session`
  - `send_prompt_async/4`: `POST <base_url>/session/:id/prompt_async` with `%{parts: parts}`
  - `abort_session/2`: `POST <base_url>/session/:id/abort`
  - `subscribe_events/2`: `GET <base_url>/event` as SSE stream, spawns linked process that parses SSE and sends `{:opencode_event, event}` to `caller_pid`
- [ ] **REFACTOR**: Extract SSE parsing into separate private module or function

### Phase 6 Validation

- [ ] All client tests pass with Bypass
- [ ] No boundary violations

---

## Phase 7: Dockerfile + opencode.json ✓

**Goal**: Container image definition for running opencode serve.

### 7.1 Dockerfile

- [ ] Create `infra/opencode/Dockerfile`:
  ```dockerfile
  FROM oven/bun:latest
  RUN bun install -g opencode-ai@latest
  WORKDIR /workspace
  COPY opencode.json /workspace/opencode.json
  EXPOSE 4096
  ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
  ```

### 7.2 opencode.json

- [ ] Create `infra/opencode/opencode.json`:
  ```json
  {
    "$schema": "https://opencode.ai/config.json",
    "provider": "anthropic",
    "model": "claude-sonnet-4-20250514",
    "permissions": {
      "allowed_tools": ["*"]
    }
  }
  ```

### 7.3 Docker Build Verification

- [ ] Verify `docker build -t perme8-opencode infra/opencode/` succeeds
- [ ] Verify `docker run --rm perme8-opencode --help` prints opencode help (quick sanity check)

### Phase 7 Validation

- [ ] Dockerfile builds successfully
- [ ] Container runs `opencode serve` (manual verification)

---

## Phase 8: Infrastructure -- TaskRunner GenServer + Supervisor + Registry ✓

**Goal**: The core orchestration piece -- one GenServer per task managing the full lifecycle.

### 8.1 TaskRegistry + TaskRunnerSupervisor (OTP Setup)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_supervisor_test.exs`
  - Test `start_child/1` starts a TaskRunner process
  - Test process is registered in `Agents.Sessions.TaskRegistry`
  - Test process can be found via `Registry.lookup/2`
  - Use `Agents.DataCase` (needs DB for task fixture)
- [ ] **GREEN**: Implement:
  - `apps/agents/lib/agents/sessions/infrastructure/task_runner_supervisor.ex`:
    ```elixir
    defmodule Agents.Sessions.Infrastructure.TaskRunnerSupervisor do
      use DynamicSupervisor

      def start_link(init_arg) do
        DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
      end

      @impl true
      def init(_init_arg) do
        DynamicSupervisor.init(strategy: :one_for_one)
      end

      def start_child(task_id, opts \\ []) do
        spec = {Agents.Sessions.Infrastructure.TaskRunner, {task_id, opts}}
        DynamicSupervisor.start_child(__MODULE__, spec)
      end
    end
    ```
  - Register `Agents.Sessions.TaskRegistry` (a `Registry`) in `Agents.OTPApp`
  - Register `Agents.Sessions.Infrastructure.TaskRunnerSupervisor` in `Agents.OTPApp`
- [ ] **REFACTOR**: Clean up

### 8.2 TaskRunner GenServer -- Init & Container Start

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner/init_test.exs`
  - Test `init/1` sets initial state with task_id, status `:starting`, empty events list
  - Test `init/1` sends `:start_container` message to self
  - Test `handle_info(:start_container, state)` calls `container_provider.start/2`
  - Test on container start success: updates task status to `"starting"`, stores `container_id` and `port`, sends `:wait_for_health`
  - Test on container start failure: updates task status to `"failed"`, stores error, terminates
  - Use Mox for `container_provider`, `opencode_client`, `task_repo`
  - Use `Agents.DataCase`
- [ ] **GREEN**: Implement initial TaskRunner in `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - `use GenServer`
  - `def start_link({task_id, opts})` with `name: via_tuple(task_id)`
  - `via_tuple/1`: `{:via, Registry, {Agents.Sessions.TaskRegistry, task_id}}`
  - `init/1`: Load task, set state, `send(self(), :start_container)`
  - `handle_info(:start_container, state)`: Call container_provider.start
  - DI via opts: `container_provider`, `opencode_client`, `task_repo`, `pubsub`
- [ ] **REFACTOR**: Extract helper functions

### 8.3 TaskRunner GenServer -- Health Check Polling

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner/health_check_test.exs`
  - Test `handle_info(:wait_for_health, state)` calls `opencode_client.health/1`
  - Test on health `:ok`: sends `:create_session` message
  - Test on health error with retries remaining: schedules next `:wait_for_health` after interval
  - Test on health error with no retries remaining: updates task to `"failed"`, stops container, terminates
  - Test decrements retry count on each failure
  - Use Mox
- [ ] **GREEN**: Add health check handling to `task_runner.ex`
  - `handle_info(:wait_for_health, state)`: Poll health with configurable interval and max retries
  - Track `health_retries` in state
  - On success, send `:create_session`
  - On failure with retries exhausted, fail task and cleanup
- [ ] **REFACTOR**: Clean up

### 8.4 TaskRunner GenServer -- Session Create & Event Subscribe

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner/session_test.exs`
  - Test `handle_info(:create_session, state)` calls `opencode_client.create_session/2`
  - Test on success: stores `session_id`, calls `subscribe_events`, sends `:send_prompt`
  - Test on failure: updates task to `"failed"`, stops container, terminates
  - Test `handle_info(:send_prompt, state)` calls `opencode_client.send_prompt_async/4`
  - Test on prompt send success: updates task status to `"running"`, broadcasts `{:task_status_changed, task_id, "running"}` via PubSub
  - Test on prompt send failure: updates task to `"failed"`, stops container, terminates
  - Use Mox
- [ ] **GREEN**: Add session/prompt handling to `task_runner.ex`
  - `handle_info(:create_session, state)`: Create session, subscribe to events
  - `handle_info(:send_prompt, state)`: Send user instruction as prompt
  - Update task status in DB and broadcast via PubSub
- [ ] **REFACTOR**: Clean up

### 8.5 TaskRunner GenServer -- Event Streaming

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs`
  - Test `handle_info({:opencode_event, event}, state)` appends event to state and broadcasts `{:task_event, task_id, event}` via PubSub
  - Test accumulates events in GenServer state
  - Test event broadcast uses `Jarga.PubSub` on topic `"task:#{task_id}"`
  - Use Mox + PubSub subscription in test process
- [ ] **GREEN**: Add event handling to `task_runner.ex`
  - `handle_info({:opencode_event, event}, state)`: Append to events list, broadcast via PubSub
  - PubSub topic: `"task:#{task_id}"`
  - Broadcast format: `{:task_event, task_id, event}`
- [ ] **REFACTOR**: Clean up

### 8.6 TaskRunner GenServer -- Completion & Cleanup

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner/completion_test.exs`
  - Test detects completion from SSE event (message.completed or similar)
  - Test on completion: updates task to `"completed"` with `completed_at`, stops container, broadcasts status change, terminates GenServer
  - Test on error event: updates task to `"failed"` with error message, stops container, terminates
  - Test `:timeout` message: updates task to `"failed"` with "Task timed out", stops container, terminates
  - Test `handle_info(:cancel, state)` calls `opencode_client.abort_session/2`, updates task to `"cancelled"`, stops container, terminates
  - Test `terminate/2` ensures container is stopped (defensive cleanup)
  - Use Mox
- [ ] **GREEN**: Add completion/cleanup handling to `task_runner.ex`
  - Detect completion events from SSE stream
  - `handle_info(:timeout, state)`: Configurable task timeout (default 10 min)
  - `handle_info(:cancel, state)`: Abort opencode session, stop container
  - `terminate/2`: Defensive container stop
  - Set timeout via `Process.send_after(self(), :timeout, task_timeout_ms)` in init
- [ ] **REFACTOR**: Extract cleanup into shared helper

### 8.7 Update OTP Application

- [ ] Modify `apps/agents/lib/agents/otp_app.ex` to add:
  ```elixir
  # In children list:
  {Registry, keys: :unique, name: Agents.Sessions.TaskRegistry},
  Agents.Sessions.Infrastructure.TaskRunnerSupervisor
  ```

### Phase 8 Validation

- [ ] All TaskRunner tests pass
- [ ] DynamicSupervisor + Registry starts correctly
- [ ] No boundary violations (`mix compile`)

---

## Phase 9: Facade -- `Agents.Sessions` Module + Boundary Config ✓

**Goal**: Public API facade for the Sessions bounded context.

### 9.1 Agents.Sessions Facade

- [ ] **RED**: Write test `apps/agents/test/agents/sessions_test.exs`
  - Test `Agents.Sessions.create_task/2` delegates to CreateTask use case
  - Test `Agents.Sessions.cancel_task/2` delegates to CancelTask use case
  - Test `Agents.Sessions.get_task/2` delegates to GetTask use case
  - Test `Agents.Sessions.list_tasks/1` delegates to ListTasks use case
  - Integration test: create a task with real DB (no container mocking -- just test facade delegation)
  - Use `Agents.DataCase`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions.ex`
  ```elixir
  defmodule Agents.Sessions do
    use Boundary,
      top_level?: true,
      deps: [
        Agents.Sessions.Domain,
        Agents.Sessions.Application,
        Agents.Sessions.Infrastructure,
        Identity.Repo
      ],
      exports: [
        {Domain.Entities.Task, []}
      ]

    alias Agents.Sessions.Application.UseCases.{CreateTask, CancelTask, GetTask, ListTasks}

    @doc "Creates a new coding task. Returns {:ok, task} or {:error, reason}."
    @spec create_task(map(), keyword()) :: {:ok, struct()} | {:error, term()}
    def create_task(attrs, opts \\ []) do
      CreateTask.execute(attrs, opts)
    end

    @doc "Cancels a running task."
    @spec cancel_task(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
    def cancel_task(task_id, user_id, opts \\ []) do
      CancelTask.execute(task_id, user_id, opts)
    end

    @doc "Gets a task by ID with ownership check."
    @spec get_task(String.t(), String.t(), keyword()) :: {:ok, struct()} | {:error, :not_found}
    def get_task(task_id, user_id, opts \\ []) do
      GetTask.execute(task_id, user_id, opts)
    end

    @doc "Lists tasks for a user, most recent first."
    @spec list_tasks(String.t(), keyword()) :: [struct()]
    def list_tasks(user_id, opts \\ []) do
      ListTasks.execute(user_id, opts)
    end
  end
  ```
- [ ] **REFACTOR**: Clean up

### 9.2 Update Agents Facade Boundary

- [ ] Update `apps/agents/lib/agents.ex` boundary deps to include `Agents.Sessions`:
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [
      Agents.Domain,
      Agents.Application,
      Agents.Infrastructure,
      Agents.Sessions,  # <-- ADD
      Identity.Repo,
      EntityRelationshipManager
    ],
    exports: [
      {Domain.Entities.Agent, []},
      {Sessions.Domain.Entities.Task, []}  # <-- ADD (re-export for JargaWeb)
    ]
  ```

### 9.3 Update JargaWeb Boundary

- [ ] Update `apps/jarga_web/lib/jarga_web.ex` boundary deps to include `Agents.Sessions`:
  - Add `Agents.Sessions` to deps (or access via `Agents` if re-exported)

### Phase 9 Validation

- [ ] Facade tests pass
- [ ] `mix compile` shows no boundary warnings
- [ ] Full `mix test apps/agents/` passes

---

## Phase 10: LiveView -- Sessions Page + Form + Log + PubSub ✓

**Goal**: Dedicated LiveView page for running coding sessions.

### 10.1 Route Setup

- [ ] Add route to `apps/jarga_web/lib/router.ex` inside the `:app` `live_session`:
  ```elixir
  live("/sessions", AppLive.Sessions.Index, :index)
  ```
- [ ] Add sidebar navigation link in `apps/jarga_web/lib/components/layouts.ex`:
  ```heex
  <li>
    <.link navigate={~p"/app/sessions"} class="flex items-center gap-3">
      <.icon name="hero-command-line" class="size-5" />
      <span>Sessions</span>
    </.link>
  </li>
  ```

### 10.2 Sessions LiveView

- [ ] **RED**: Write test `apps/jarga_web/test/jarga_web/live/app_live/sessions/index_test.exs`
  - **Mount tests**:
    - Test renders page with "Sessions" heading
    - Test renders instruction textarea
    - Test renders "Run" submit button
    - Test renders empty state when no tasks exist
    - Test loads task history on mount
  - **Form submission tests**:
    - Test submitting instruction creates a task and shows it in the log
    - Test "Run" button is disabled when a task is running (streaming state)
    - Test empty instruction shows validation error
  - **Real-time event tests**:
    - Test receiving `{:task_event, task_id, event}` appends to event log
    - Test receiving `{:task_status_changed, task_id, "completed"}` re-enables Run button
    - Test receiving `{:task_status_changed, task_id, "failed"}` shows error in UI
  - **Cancel tests**:
    - Test cancel button appears when task is running
    - Test clicking cancel calls `Agents.Sessions.cancel_task/2`
  - Setup: `setup :register_and_log_in_user`
  - Use `JargaWeb.ConnCase`
- [ ] **GREEN**: Implement `apps/jarga_web/lib/live/app_live/sessions/index.ex`
  - `use JargaWeb, :live_view`
  - `mount/3`: Load user's tasks, subscribe to PubSub if connected
  - `render/1`: Admin layout with:
    - Textarea + "Run" button form (`id="session-form"`)
    - Event log container (`id="session-log"`, `phx-hook="SessionLog"`, `phx-update="ignore"`)
    - Cancel button (shown when task running)
  - `handle_event("run_task", params, socket)`: Call `Agents.Sessions.create_task/2`, subscribe to task topic
  - `handle_event("cancel_task", _, socket)`: Call `Agents.Sessions.cancel_task/2`
  - `handle_info({:task_event, task_id, event}, socket)`: Append event to assigns, push to log
  - `handle_info({:task_status_changed, task_id, status}, socket)`: Update task status in assigns
  - Assigns: `events`, `current_task`, `tasks`, `form`
- [ ] **REFACTOR**: Keep thin, delegate all business logic to `Agents.Sessions`

### 10.3 Sessions LiveView Template

- [ ] Create `apps/jarga_web/lib/live/app_live/sessions/index.html.heex`
  - Admin layout wrapper: `<Layouts.admin flash={@flash} current_scope={@current_scope}>`
  - Header with breadcrumbs
  - Instruction form: `<.form for={@form} id="session-form" phx-submit="run_task">`
  - Textarea: `<textarea name="instruction" id="session-instruction" rows="3" ...>`
  - Run button: `<.button type="submit" id="run-task-btn" disabled={@current_task && @current_task.status in ["pending", "starting", "running"]}>`
  - Event log: `<div id="session-log" phx-hook="SessionLog" phx-update="ignore" class="...">`
  - Cancel button: `<.button id="cancel-task-btn" phx-click="cancel_task" :if={...}>`

### 10.4 AutoScroll JS Hook

The codebase uses class-based hooks registered via `apps/jarga_web/assets/js/hooks.ts`. Follow the existing pattern from `ChatPanelHook`, `FlashHook` etc.

- [ ] Create `apps/jarga_web/assets/js/presentation/hooks/session-log-hook.ts`:
  ```typescript
  /**
   * SessionLogHook
   *
   * Auto-scrolls the session event log container as new events arrive.
   * Respects user scroll position -- only auto-scrolls if user is at the bottom.
   */
  export class SessionLogHook {
    el!: HTMLElement;
    handleEvent!: (event: string, callback: (payload: any) => void) => void;
    private isAtBottom: boolean = true;

    mounted() {
      this.isAtBottom = true;
      this.el.addEventListener("scroll", () => {
        const { scrollTop, scrollHeight, clientHeight } = this.el;
        this.isAtBottom = scrollHeight - scrollTop - clientHeight < 50;
      });

      this.handleEvent("append_event", ({ html }: { html: string }) => {
        this.el.insertAdjacentHTML("beforeend", html);
        if (this.isAtBottom) {
          this.el.scrollTop = this.el.scrollHeight;
        }
      });
    }
  }
  ```
- [ ] Register in `apps/jarga_web/assets/js/hooks.ts`:
  ```typescript
  import { SessionLogHook } from './presentation/hooks/session-log-hook'
  // Add to exports and default export:
  export default {
    // ...existing hooks...
    SessionLog: SessionLogHook
  }
  ```

### Phase 10 Validation

- [ ] All LiveView tests pass
- [ ] Form submission works
- [ ] Real-time events render in log
- [ ] Cancel button works
- [ ] No boundary violations

---

## Phase 11: LiveView -- Task History + Status Indicators ✓

**Goal**: Task history list with status indicators.

### 11.1 Task History Component

- [ ] **RED**: Write test `apps/jarga_web/test/jarga_web/live/app_live/sessions/history_test.exs`
  - Test renders list of past tasks with instruction (truncated to 80 chars)
  - Test renders colour-coded status indicators:
    - `pending` / `starting` -- yellow/amber
    - `running` -- blue with pulse animation
    - `completed` -- green
    - `failed` -- red
    - `cancelled` -- gray
  - Test renders relative timestamps
  - Test clicking a completed task does NOT load events (events not persisted)
  - Test clicking a running task subscribes to its PubSub topic and shows live events
  - Use `JargaWeb.ConnCase`
- [ ] **GREEN**: Enhance `apps/jarga_web/lib/live/app_live/sessions/index.ex` with:
  - Task history section in template (below the event log)
  - Status badge helper function component
  - Instruction truncation helper
  - Relative time helper (reuse pattern from `ChatLive.Panel`)
  - `handle_event("view_task", %{"task-id" => task_id}, socket)`: Switch current task view, subscribe to PubSub topic if running
- [ ] **REFACTOR**: Extract status badge into a shared component if reusable

### 11.2 Status Badge Component

- [ ] Create function component in `apps/jarga_web/lib/live/app_live/sessions/index.ex` (or a shared components file):
  ```elixir
  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @status == "pending" && "badge-warning",
      @status == "starting" && "badge-warning",
      @status == "running" && "badge-info animate-pulse",
      @status == "completed" && "badge-success",
      @status == "failed" && "badge-error",
      @status == "cancelled" && "badge-ghost"
    ]}>
      {@status}
    </span>
    """
  end
  ```

### Phase 11 Validation

- [ ] Task history renders correctly
- [ ] Status indicators show correct colours
- [ ] Full test suite passes: `mix test`

---

## Phase 12: Persistent Container Lifecycle — Stop vs Remove (2026-02-22)

**Goal**: Containers survive task completion for resume and historical output retrieval. Only destroyed on explicit user delete.

### 12.1 ContainerProviderBehaviour — New Callbacks

- [ ] Update `apps/agents/lib/agents/sessions/application/behaviours/container_provider_behaviour.ex`:
  - Rename existing `stop/1` semantics — it now means graceful stop (preserves container)
  - Add `@callback remove(container_id :: String.t()) :: :ok | {:error, term()}` — permanent destruction
  - Add `@callback restart(container_id :: String.t()) :: {:ok, %{port: integer()}} | {:error, term()}` — restart stopped container, re-discover port

### 12.2 DockerAdapter — Stop, Remove, Restart

- [ ] **RED**: Write/update tests in `docker_adapter_test.exs`
  - Test `stop/1` runs `docker stop` (not `docker rm -f`)
  - Test `remove/1` runs `docker rm -f`
  - Test `restart/1` runs `docker start`, then `docker port` to discover new mapped port
  - Test `restart/1` returns `{:ok, %{port: port}}` on success
  - Test `restart/1` returns `{:error, reason}` when container doesn't exist
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/adapters/docker_adapter.ex`
  - `stop/1` → `docker stop <id>` (was `docker rm -f`)
  - `remove/1` → `docker rm -f <id>` (new function, permanent destruction)
  - `restart/1` → `docker start <id>`, then `docker port <id> 4096` with retry logic
- [ ] **REFACTOR**: Clean up, ensure port discovery retry works for restart path too

### 12.3 TaskRunner — Stop Instead of Remove

- [ ] Update `task_runner.ex`:
  - `cleanup_container/1` calls `stop/1` (preserves container)
  - Save `session_id` to DB when opencode session is created (in `:create_session` handler)
  - Accumulate assistant text output in GenServer state (`output_text` field)
  - In `complete_task/1`, save `output` to DB along with status/completed_at

### 12.4 DeleteTask — Remove Container on Delete

- [ ] Update `apps/agents/lib/agents/sessions/application/use_cases/delete_task.ex`:
  - After ownership + deletability validation, call `container_provider.remove/1` to destroy the container
  - Then delete the DB row
  - Handle case where container is already gone (idempotent)
- [ ] Update tests for new container removal step

### Phase 12 Validation

- [ ] `docker stop` is used for task completion (container preserved)
- [ ] `docker rm -f` only used on explicit delete
- [ ] `session_id` is persisted to DB
- [ ] Output text is cached in DB `output` column on completion
- [ ] All existing tests still pass

---

## Phase 13: Opencode Retrieval APIs

**Goal**: Add read APIs to the opencode client for fetching session history from a stopped-then-restarted container.

### 13.1 OpencodeClientBehaviour — New Callbacks

- [ ] Update `apps/agents/lib/agents/sessions/application/behaviours/opencode_client_behaviour.ex`:
  - Add `@callback list_sessions(base_url :: String.t(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}`
  - Add `@callback get_session(base_url :: String.t(), session_id :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}`
  - Add `@callback get_messages(base_url :: String.t(), session_id :: String.t(), opts :: keyword()) :: {:ok, [map()]} | {:error, term()}`

### 13.2 OpencodeClient — Retrieval Implementations

- [ ] **RED**: Write tests in `opencode_client_test.exs`
  - Test `list_sessions/2` → `GET /session` returns session list
  - Test `get_session/3` → `GET /session/{id}` returns session details
  - Test `get_messages/3` → `GET /session/{id}/message` returns message list with parts
  - Test error handling for all three
- [ ] **GREEN**: Implement in `opencode_client.ex`
  - `list_sessions/2` → `GET <base_url>/session`
  - `get_session/3` → `GET <base_url>/session/<session_id>`
  - `get_messages/3` → `GET <base_url>/session/<session_id>/message`
- [ ] **REFACTOR**: Clean up

### Phase 13 Validation

- [ ] All retrieval API tests pass
- [ ] Mock definitions updated for new callbacks

---

## Phase 14: Schema + Entity — Output Cache + Parent Task

**Goal**: Add `output` column for cached assistant text and `parent_task_id` for resume chains.

### 14.1 Migration — Add output and parent_task_id columns

- [ ] Create migration `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_add_output_and_parent_task_to_sessions_tasks.exs`:
  - `add(:output, :text)` — cached assistant output (already created as standalone migration)
  - `add(:parent_task_id, references(:sessions_tasks, type: :binary_id, on_delete: :nilify_all))` — links follow-up tasks to their parent

### 14.2 TaskSchema — New Fields

- [ ] Update `task_schema.ex`:
  - Add `field(:output, :string)` to schema
  - Add `belongs_to(:parent_task, TaskSchema, type: Ecto.UUID)` or `field(:parent_task_id, Ecto.UUID)`
  - Add `:output` to `status_changeset` cast fields
  - Add `:parent_task_id` to `changeset` cast fields

### 14.3 Domain Entity — New Fields

- [ ] Update `task.ex`:
  - Add `:output` and `:parent_task_id` to struct, typespec, and `from_schema/1`

### Phase 14 Validation

- [ ] Migration runs successfully
- [ ] Schema and entity tests updated
- [ ] All existing tests pass

---

## Phase 15: View Historical Output

**Goal**: When a user clicks a completed task, show the cached output (or lazy-load it from the container).

### 15.1 LiveView — Display Cached Output

- [ ] Update `view_task` handler in `index.ex`:
  - For completed/failed tasks with cached `output`: parse into `output_parts` immediately
  - For completed tasks without cached `output` (legacy data): show loading state, attempt async container restart + message fetch
- [ ] Add helper to parse raw output text into `output_parts` (text parts only for cached data)

### 15.2 Async Output Fetching (Fallback)

- [ ] Implement async output loading when no cache exists:
  1. Restart container (`DockerAdapter.restart/1`)
  2. Wait for health check
  3. Fetch messages (`OpencodeClient.get_messages/3`)
  4. Parse into output text
  5. Cache to DB (`output` column)
  6. Stop container
  7. Send result back to LiveView via `send/2`
- [ ] LiveView handles `{:output_loaded, task_id, output_parts}` message

### Phase 15 Validation

- [ ] Cached output displays immediately on click
- [ ] Fallback loading works for tasks without cached output
- [ ] LiveView tests updated

---

## Phase 16: Resume Sessions — Follow-Up Instructions

**Goal**: Users can send follow-up instructions to an existing session, creating a new linked task.

### 16.1 ResumeTask Use Case

- [ ] Create `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex`:
  - `execute(parent_task_id, attrs, opts)` — creates a new task linked via `parent_task_id`
  - Validates parent task is in a terminal state (completed/failed)
  - Reuses `container_id` and `session_id` from parent task
  - Starts a new TaskRunner that:
    1. Restarts the container (not creates a new one)
    2. Health check
    3. Sends new prompt to existing session (no `create_session`)
    4. Streams events via PubSub
    5. On completion: stops container, caches output

### 16.2 Facade — Resume

- [ ] Add `resume_task/3` to `Agents.Sessions` facade:
  ```elixir
  @spec resume_task(String.t(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def resume_task(parent_task_id, attrs, opts \\ [])
  ```

### 16.3 LiveView — Resume UX

- [ ] When viewing a completed task, the instruction form becomes a "resume" form:
  - Form submits to `resume_task` instead of `run_task`
  - New task appears in history linked to the parent
  - Same real-time streaming as initial task

### Phase 16 Validation

- [ ] Resume creates a new task linked to the parent
- [ ] Container is restarted (not recreated)
- [ ] Prompt is sent to existing opencode session
- [ ] Output streams in real-time
- [ ] Full test suite passes

---

## Pre-Commit Checkpoint

- [ ] `mix compile` -- no warnings
- [ ] `mix boundary` -- no violations
- [ ] `mix format` -- code formatted
- [ ] `mix credo` -- no issues
- [ ] `mix test` -- all tests pass
- [ ] `mix precommit` -- full pre-commit suite passes

---

## Testing Strategy

### Total Estimated Tests: ~65-75

| Layer | Location | Count | Speed |
|-------|----------|-------|-------|
| Domain entities | `test/agents/sessions/domain/entities/` | 6-8 | ms |
| Domain events | `test/agents/sessions/domain/events/` | 6-8 | ms |
| Domain policies | `test/agents/sessions/domain/policies/` | 8-10 | ms |
| Application behaviours | `test/agents/sessions/application/behaviours/` | 3-4 | ms |
| Application config | `test/agents/sessions/application/` | 5-6 | ms |
| Application use cases | `test/agents/sessions/application/use_cases/` | 12-15 | fast (mocked) |
| Infrastructure schemas | `test/agents/sessions/infrastructure/schemas/` | 5-7 | fast (DB) |
| Infrastructure queries | `test/agents/sessions/infrastructure/queries/` | 5-6 | fast (DB) |
| Infrastructure repository | `test/agents/sessions/infrastructure/repositories/` | 6-8 | fast (DB) |
| Infrastructure adapters | `test/agents/sessions/infrastructure/adapters/` | 6-8 | fast (mocked) |
| Infrastructure client | `test/agents/sessions/infrastructure/clients/` | 5-7 | fast (Bypass) |
| Infrastructure TaskRunner | `test/agents/sessions/infrastructure/task_runner/` | 12-16 | fast (mocked) |
| Facade | `test/agents/sessions_test.exs` | 4-5 | fast (DB) |
| LiveView | `test/jarga_web/live/app_live/sessions/` | 12-15 | moderate |

### Distribution
- **Domain**: ~20-26 tests (pure, millisecond speed)
- **Application**: ~20-25 tests (mocked, fast)
- **Infrastructure**: ~34-45 tests (DB/Bypass, fast)
- **Interface**: ~12-15 tests (LiveView, moderate)

---

## Acceptance Criteria Mapping

| Acceptance Criterion | Phase |
|---|---|
| `Agents.Sessions` bounded context with clean architecture | Phases 1-9 |
| Task entity with DB persistence | Phases 1, 2 |
| ContainerProvider behaviour with Docker adapter | Phases 3, 5, 12 |
| OpencodeClient behaviour with Req-based HTTP/SSE implementation | Phases 3, 6, 13 |
| Dockerfile that runs `opencode serve` in a container | Phase 7 |
| TaskRunner GenServer managing full lifecycle | Phase 8, 12 |
| Concurrent task limit of 1 (configurable) | Phases 4 (CreateTask validation) |
| Events streamed in real-time via PubSub (in-memory, not persisted) | Phases 8, 10 |
| Dedicated LiveView page with instruction input and scrolling log | Phase 10 |
| Real-time event streaming from container to UI via PubSub | Phases 8, 10 |
| Cancel running task from UI | Phases 4, 10 |
| Task history with status indicators | Phase 11 |
| LLM provider API keys passed as env vars to container | Phase 5 (DockerAdapter reads config) |
| 10-minute timeout with configurable default | Phase 8 (TaskRunner timeout) |
| Persistent containers — stop on completion, remove on delete | Phase 12 |
| Session ID persisted to DB for resume | Phase 12 |
| Output cached in DB for instant historical viewing | Phases 12, 14 |
| Opencode retrieval APIs (list sessions, get messages) | Phase 13 |
| View historical task output from cached DB data | Phase 15 |
| Lazy-load output from container when cache is empty | Phase 15 |
| Resume sessions with follow-up instructions | Phase 16 |
| New task per instruction, linked via parent_task_id | Phases 14, 16 |
| Delete session destroys container (docker rm) | Phase 12 |
| Auto-cleanup on PR merge/close | Future (webhooks app dependency) |

---

## File Reference: All Files to Create

### Domain Layer (`apps/agents/lib/agents/sessions/`)
1. `domain.ex` -- Domain boundary
2. `domain/entities/task.ex` -- Task entity
3. `domain/events/task_created.ex` -- TaskCreated event
4. `domain/events/task_status_changed.ex` -- TaskStatusChanged event
5. `domain/policies/task_policy.ex` -- TaskPolicy

### Application Layer
6. `application.ex` -- Application boundary
7. `application/behaviours/task_repository_behaviour.ex`
8. `application/behaviours/container_provider_behaviour.ex`
9. `application/behaviours/opencode_client_behaviour.ex`
10. `application/sessions_config.ex` -- Config accessor
11. `application/use_cases/create_task.ex`
12. `application/use_cases/cancel_task.ex`
13. `application/use_cases/get_task.ex`
14. `application/use_cases/list_tasks.ex`

### Infrastructure Layer
15. `infrastructure.ex` -- Infrastructure boundary
16. `infrastructure/schemas/task_schema.ex`
17. `infrastructure/queries/task_queries.ex`
18. `infrastructure/repositories/task_repository.ex`
19. `infrastructure/adapters/docker_adapter.ex`
20. `infrastructure/clients/opencode_client.ex`
21. `infrastructure/task_runner.ex` -- TaskRunner GenServer
22. `infrastructure/task_runner_supervisor.ex` -- DynamicSupervisor

### Facade
23. `sessions.ex` -- Public API facade

### Interface Layer (`apps/jarga_web/lib/live/app_live/sessions/`)
24. `index.ex` -- Sessions LiveView
25. `index.html.heex` -- Sessions template (or inline render)

### Infrastructure (Docker)
26. `infra/opencode/Dockerfile`
27. `infra/opencode/opencode.json`

### Migration
28. `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_create_sessions_tasks.exs`

### Test Files
29. `apps/agents/test/agents/sessions/domain/entities/task_test.exs`
30. `apps/agents/test/agents/sessions/domain/events/task_created_test.exs`
31. `apps/agents/test/agents/sessions/domain/events/task_status_changed_test.exs`
32. `apps/agents/test/agents/sessions/domain/policies/task_policy_test.exs`
33. `apps/agents/test/agents/sessions/application/behaviours/task_repository_behaviour_test.exs`
34. `apps/agents/test/agents/sessions/application/behaviours/container_provider_behaviour_test.exs`
35. `apps/agents/test/agents/sessions/application/behaviours/opencode_client_behaviour_test.exs`
36. `apps/agents/test/agents/sessions/application/sessions_config_test.exs`
37. `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs`
38. `apps/agents/test/agents/sessions/application/use_cases/cancel_task_test.exs`
39. `apps/agents/test/agents/sessions/application/use_cases/get_task_test.exs`
40. `apps/agents/test/agents/sessions/application/use_cases/list_tasks_test.exs`
41. `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_test.exs`
42. `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs`
43. `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs`
44. `apps/agents/test/agents/sessions/infrastructure/adapters/docker_adapter_test.exs`
45. `apps/agents/test/agents/sessions/infrastructure/clients/opencode_client_test.exs`
46. `apps/agents/test/agents/sessions/infrastructure/task_runner_supervisor_test.exs`
47. `apps/agents/test/agents/sessions/infrastructure/task_runner/init_test.exs`
48. `apps/agents/test/agents/sessions/infrastructure/task_runner/health_check_test.exs`
49. `apps/agents/test/agents/sessions/infrastructure/task_runner/session_test.exs`
50. `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs`
51. `apps/agents/test/agents/sessions/infrastructure/task_runner/completion_test.exs`
52. `apps/agents/test/agents/sessions_test.exs`
53. `apps/agents/test/support/fixtures/sessions_fixtures.ex`
54. `apps/jarga_web/test/jarga_web/live/app_live/sessions/index_test.exs`
55. `apps/jarga_web/test/jarga_web/live/app_live/sessions/history_test.exs`

### Config Changes
56. `config/config.exs` -- Add `:sessions` and `:sessions_env` config
57. `config/test.exs` -- Add test-specific `:sessions` config
58. `apps/agents/test/test_helper.exs` -- Add Mox mock definitions

### Existing File Modifications
59. `apps/agents/lib/agents/otp_app.ex` -- Add Registry + DynamicSupervisor children
60. `apps/agents/lib/agents.ex` -- Update boundary deps/exports
61. `apps/jarga_web/lib/router.ex` -- Add `/app/sessions` route
62. `apps/jarga_web/lib/components/layouts.ex` -- Add sidebar link
63. `apps/jarga_web/lib/jarga_web.ex` -- Update boundary deps (if needed)
64. `apps/jarga_web/assets/js/presentation/hooks/session-log-hook.ts` -- SessionLog JS hook
65. `apps/jarga_web/assets/js/hooks.ts` -- Register hook in hooks barrel file

### Phase 12-16 Additions (Persistent Containers + Resume)
66. `application/use_cases/resume_task.ex` -- ResumeTask use case
67. `apps/agents/test/agents/sessions/application/use_cases/resume_task_test.exs`
68. `apps/jarga/priv/repo/migrations/YYYYMMDDHHMMSS_add_output_and_parent_task_to_sessions_tasks.exs`

### Phase 12-16 Modifications
- `application/behaviours/container_provider_behaviour.ex` -- Add `remove/1`, `restart/1` callbacks
- `application/behaviours/opencode_client_behaviour.ex` -- Add `list_sessions/2`, `get_session/3`, `get_messages/3` callbacks
- `infrastructure/adapters/docker_adapter.ex` -- Stop vs remove vs restart separation
- `infrastructure/clients/opencode_client.ex` -- Retrieval API implementations
- `infrastructure/task_runner.ex` -- Stop (not remove) on cleanup, save session_id and output
- `infrastructure/schemas/task_schema.ex` -- Add `output`, `parent_task_id` fields
- `domain/entities/task.ex` -- Add `output`, `parent_task_id` fields
- `application/use_cases/delete_task.ex` -- Call container remove before DB delete
- `sessions.ex` -- Add `resume_task/3` facade function
- `apps/jarga_web/lib/live/app_live/sessions/index.ex` -- Historical output display, resume UX

---

## Notes for Implementers

1. **Migrations go in `apps/jarga/priv/repo/migrations/`** -- this is the shared migration path. The agents app uses `Identity.Repo` (aliased as `Repo`) which points to the same Postgres database.

2. **Timestamps use `:utc_datetime_usec`** -- the ticket explicitly specifies microsecond precision. This differs from some existing schemas that use `:utc_datetime`.

3. **PubSub uses `Jarga.PubSub`** -- this is the global PubSub server. Use `Phoenix.PubSub.broadcast(Jarga.PubSub, topic, message)` for broadcasts.

4. **Events are NOT persisted** -- events are held in TaskRunner GenServer state and broadcast via PubSub. When the GenServer terminates, events are lost. The LiveView accumulates events in assigns for display. However, assistant text output is **cached in the DB `output` column** when the task completes, so historical tasks can display output without restarting the container.

5. **TaskRunner naming**: `{:via, Registry, {Agents.Sessions.TaskRegistry, task_id}}` -- this enables looking up a running TaskRunner by task_id.

6. **Docker CLI dependency**: The DockerAdapter uses `System.cmd/3` to interact with Docker. In tests, inject a mock `system_cmd` function to avoid requiring Docker. In production/dev, the real `System.cmd/3` is used.

7. **SSE parsing**: The opencode server streams events as Server-Sent Events. The `subscribe_events/2` function spawns a process that keeps an HTTP connection open and parses the SSE stream, forwarding each event as `{:opencode_event, event}` to the caller pid.

8. **Concurrent limit**: The `CreateTask` use case checks `task_repo.running_task_count_for_user/1` before creating a new task. The limit is configurable via `SessionsConfig.max_concurrent_tasks/0`.

9. **Container lifecycle: stop vs remove** -- `DockerAdapter.stop/1` calls `docker stop` (preserves container for resume). `DockerAdapter.remove/1` calls `docker rm -f` (permanent destruction). TaskRunner calls `stop` on completion/failure/cancel. DeleteTask calls `remove` on explicit user delete.

10. **Session ID persistence** -- TaskRunner saves the opencode `session_id` to the DB when the session is created. This enables resume (send new prompt to same session) and message retrieval for historical output.

11. **Container restart** -- `DockerAdapter.restart/1` calls `docker start` + port re-discovery. Used when viewing historical output (if no cached output) or resuming a session with a new instruction.

12. **Opencode retrieval APIs** -- The opencode SDK exposes `GET /session` (list sessions), `GET /session/{id}` (session details), and `GET /session/{id}/message` (message history with parts). These are used to fetch historical conversation data from a stopped-then-restarted container.

13. **Resume model** -- Follow-up instructions create a **new task row** linked to the same container via `parent_task_id`. Each instruction is a separate task, but they share the same Docker container and opencode session. The task history shows the full chain of instructions.
