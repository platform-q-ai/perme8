# Feature: Optimistic Sessions UI Updates with Durable Client State (#330)

## App Ownership

- **Owning domain app**: `agents`
- **Owning interface app**: `agents_web`
- **Owning Repo**: `Agents.Repo`
- **Domain path**: `apps/agents/lib/agents/`
- **Web path**: `apps/agents_web/lib/agents_web/`
- **API path**: `apps/agents_api/lib/agents_api/` (not required for this ticket)
- **Migration path**: `apps/agents/priv/repo/migrations/`
- **Boundary rule**: keep all domain/application/infrastructure logic in `agents`; keep LiveView and hook orchestration in `agents_web`; no cross-app Repo usage

## Overview

Implement deterministic optimistic follow-up handling for Sessions so users see immediate pending entries, backend receives explicit async command payloads with correlation keys, reload/reconnect restores in-flight intent, and backend acknowledgements reconcile each entry to confirmed/retried/rolled back without duplicates.

## UI Strategy

- **LiveView coverage**: ~90% (optimistic list rendering, reconciliation, retry/rollback actions, reconnect handling)
- **TypeScript needed**: Yes (targeted)
  - `localStorage` persistence/restore of optimistic client queue across full browser reload
  - per-user/per-task storage isolation and hydration handoff to LiveView
  - hook-level reconnect hydration trigger

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**:
  - `apps/agents_web/test/features/sessions/sessions-optimistic.browser.feature`
  - `apps/agents_web/test/features/sessions/sessions-optimistic.security.feature`
- **Primary context**: `Agents.Sessions`
- **Dependencies**: `Perme8.Events` (existing event bus), `Phoenix.PubSub` (existing task topic broadcast)
- **Exported schemas**: `Agents.Sessions.Domain.Entities.Task` (existing export; extended fields only)
- **New context needed?**: No; stays within `Agents.Sessions` bounded context

## Accepted BDD Alignment

- Immediate optimistic pending entry: LiveView append + hook persistence on submit
- Explicit async payload with correlation key: new command payload contract from UI to `Sessions` API and TaskRunner
- Full reload durability: localStorage + persisted task optimistic command snapshot restore
- Deterministic reconcile success/failure: correlation-keyed state machine (`pending -> confirmed` or `pending -> retriable/rolled_back`)
- Reconnect/reload deterministic behavior: LiveView + hook hydration tests and TaskRunner acknowledgement tests
- Security posture: auth/ownership validation + malformed correlation key rejection + per-user durable storage namespace

---

## Phase 1: Domain + Application (phoenix-tdd)

### OptimisticCommand Entity

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/optimistic_command_test.exs`
  - Tests: correlation key format validation, allowed states (`pending|confirmed|retriable|rolled_back`), retry counters, deterministic transition guards
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/optimistic_command.ex`
  - Pure struct + constructor/normalizer; no Repo/IO
- [ ] ⏸ **REFACTOR**: Keep serialization helpers isolated from persistence concerns

### OptimisticCommandPolicy

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/optimistic_command_policy_test.exs`
  - Tests: ownership-required transitions, malformed correlation key rejection, idempotent reconcile behavior for duplicate acknowledgements
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/optimistic_command_policy.ex`
- [ ] ⏸ **REFACTOR**: Remove duplicated guards in LiveView/TaskRunner by centralizing policy checks

### SubmitOptimisticCommand Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/submit_optimistic_command_test.exs`
  - Mocks: `task_repo`, `task_runner_gateway` (or callable), `event_bus`
  - Cases: accepts valid payload, rejects malformed correlation key, forbids cross-user task access, marks pending before async send
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/submit_optimistic_command.ex`
  - Orchestrates validation + enqueue + async dispatch trigger
- [ ] ⏸ **REFACTOR**: Ensure dependency injection via `opts` for testability

### ReconcileOptimisticCommand Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/reconcile_optimistic_command_test.exs`
  - Mocks: `task_repo`, `event_bus`
  - Cases: backend success => confirmed, backend failure => retriable/rolled_back, duplicate reconcile idempotency
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/reconcile_optimistic_command.ex`
- [ ] ⏸ **REFACTOR**: Consolidate transition branching through `OptimisticCommandPolicy`

### Public Sessions Facade Wiring

- [ ] ⏸ **RED**: Add facade contract tests `apps/agents/test/agents/sessions_test.exs`
  - New API paths for submit/retry/reconcile optimistic commands
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions.ex`
  - Add public functions for optimistic command submit/retry/reconcile
- [ ] ⏸ **REFACTOR**: Keep facade as thin delegation only

### Phase 1 Validation

- [ ] ⏸ Domain tests pass (pure, async)
- [ ] ⏸ Application tests pass (mocked dependencies)
- [ ] ⏸ `mix boundary` reports no violations

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### Migration + Schema Persistence for Optimistic Commands

- [ ] ⏸ **RED**: Add repository/query tests:
  - `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs`
  - `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs`
  - Validate optimistic command snapshot persistence and user-scoped retrieval
- [ ] ⏸ **GREEN**: Create migration `apps/agents/priv/repo/migrations/[timestamp]_add_optimistic_commands_to_sessions_tasks.exs`
  - Add `:optimistic_commands` map/jsonb column (default empty)
- [ ] ⏸ **GREEN**: Update persistence modules
  - `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex`
  - `apps/agents/lib/agents/sessions/domain/entities/task.ex`
  - `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex`
  - `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex`
- [ ] ⏸ **REFACTOR**: Keep optimistic-command serialization in dedicated helpers (no ad-hoc map mutation)

### TaskRunner Async Acknowledgement + Deterministic Correlation

- [ ] ⏸ **RED**: Add tests
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs`
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/optimistic_commands_test.exs` (new)
  - Cases: explicit payload forwarded, success ack, failure ack, duplicate ack idempotency, reconnect-safe state
- [ ] ⏸ **GREEN**: Implement in
  - `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - `apps/agents/lib/agents/sessions/infrastructure/clients/opencode_client.ex` (payload pass-through support)
  - `apps/agents/lib/agents/sessions/application/behaviours/opencode_client_behaviour.ex` (if signature expands)
- [ ] ⏸ **REFACTOR**: isolate command payload shaping into private function to avoid duplicated map assembly

### Sessions LiveView Deterministic Optimistic UI

- [ ] ⏸ **RED**: Extend LiveView + processor tests
  - `apps/agents_web/test/live/sessions/index_test.exs`
  - `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - Cases: immediate pending render, confirmed/retried/rolled_back badge transitions, no duplication on ack, restore after full reload, reconnect reconciliation
- [ ] ⏸ **GREEN**: Update LiveView modules
  - `apps/agents_web/lib/live/sessions/index.ex`
  - `apps/agents_web/lib/live/sessions/event_processor.ex`
  - `apps/agents_web/lib/live/sessions/helpers.ex`
  - `apps/agents_web/lib/live/sessions/components/session_components.ex`
  - `apps/agents_web/lib/live/sessions/index.html.heex`
  - Add explicit payload fields (`correlation_key`, `command_type`, timestamps) to submit/retry events
- [ ] ⏸ **REFACTOR**: keep render functions thin; push transition logic into helpers/event processor

### Security + Ownership Enforcement

- [ ] ⏸ **RED**: Add tests for forbidden and malformed payload paths
  - `apps/agents/test/agents/sessions/application/use_cases/submit_optimistic_command_test.exs`
  - `apps/agents_web/test/live/sessions/index_test.exs`
  - Validate unauthenticated redirect behavior remains intact in LiveView route scope
- [ ] ⏸ **GREEN**: Enforce validation in use case + facade before TaskRunner dispatch
- [ ] ⏸ **REFACTOR**: centralize correlation key validator to avoid drift

### Phase 2 Validation

- [ ] ⏸ Infrastructure tests pass
- [ ] ⏸ Interface tests pass
- [ ] ⏸ `mix ecto.migrate` succeeds
- [ ] ⏸ `mix boundary` passes
- [ ] ⏸ Full `mix test` passes

### Pre-Commit Checkpoint (after Phase 2)

- [ ] ⏸ `mix precommit`
- [ ] ⏸ `mix boundary`

---

## Phase 3: TypeScript Domain + Application (typescript-tdd)

### Optimistic Client Queue Domain Model

- [ ] ⏸ **RED**: Add unit tests `apps/agents_web/assets/js/domain/entities/optimistic-command.spec.ts`
  - Cases: key validation, immutable updates, deterministic merge from server snapshot + local cache
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/assets/js/domain/entities/optimistic-command.ts`
- [ ] ⏸ **REFACTOR**: remove UI concerns from domain model

### Client Persistence Use Cases

- [ ] ⏸ **RED**: Add tests `apps/agents_web/assets/js/application/use-cases/optimistic-state-sync.spec.ts`
  - Cases: persist on submit, restore on mount, prune on confirmed/rolled_back, user/task namespace isolation
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/assets/js/application/use-cases/optimistic-state-sync.ts`
- [ ] ⏸ **REFACTOR**: inject storage adapter for deterministic tests

### Phase 3 Validation

- [ ] ⏸ TypeScript unit tests pass (Vitest)
- [ ] ⏸ No direct DOM/LiveView calls inside domain/application files

---

## Phase 4: TypeScript Infrastructure + Presentation (typescript-tdd)

### Browser Storage Adapter

- [ ] ⏸ **RED**: Add tests `apps/agents_web/assets/js/infrastructure/storage/optimistic-state-storage.spec.ts`
  - Cases: serialization safety, corruption fallback, per-user namespace keying
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/assets/js/infrastructure/storage/optimistic-state-storage.ts`
- [ ] ⏸ **REFACTOR**: add explicit version field for forward-compatible payloads

### LiveView Hook Integration

- [ ] ⏸ **RED**: Add hook tests `apps/agents_web/assets/js/presentation/hooks/session-optimistic-state-hook.spec.ts`
  - Cases: mount hydration push, update persistence, reconnect replay, teardown cleanup
- [ ] ⏸ **GREEN**: Implement hook and wiring
  - `apps/agents_web/assets/js/presentation/hooks/session-optimistic-state-hook.ts`
  - `apps/agents_web/assets/js/hooks.ts`
  - `apps/agents_web/lib/live/sessions/index.html.heex` (hook mount data attrs)
- [ ] ⏸ **REFACTOR**: keep hook thin; delegate storage and merge logic to use cases

### BDD Traceability Updates

- [ ] ⏸ **RED/GREEN**: Update step definitions/support (if needed) to exercise new deterministic statuses and reload flow for:
  - `apps/agents_web/test/features/sessions/sessions-optimistic.browser.feature`
  - `apps/agents_web/test/features/sessions/sessions-optimistic.security.feature`
- [ ] ⏸ **REFACTOR**: remove brittle selectors; rely on deterministic DOM ids/data-testid for status assertions

### Phase 4 Validation

- [ ] ⏸ Hook tests pass
- [ ] ⏸ LiveView + hook integration tests pass for reload/reconnect
- [ ] ⏸ BDD optimistic scenarios are green

---

## Testing Strategy

- **Total estimated tests**: 44
- **Distribution**: Domain 8, Application 10, Infrastructure 13, Interface 9, TypeScript 4
- **Fast-path emphasis**: correlation/state-machine logic covered in pure tests first; LiveView/runner integration verifies orchestration and duplication prevention

## Key Risks to Manage During Implementation

- **Correlation mismatch risk**: opencode event payload may not echo client correlation key; mitigate with explicit payload contract and idempotent fallback mapping rules
- **Duplicate rendering risk**: existing text-based matching can double-render; replace with correlation-key-first reconciliation and dedicated dedupe tests
- **Reload/reconnect divergence risk**: server snapshot and local durable state may conflict; define deterministic merge precedence (server terminal states win)
- **Security leakage risk**: local durable state could leak across users on shared browser; enforce user+task namespacing and purge on identity change/logout
- **Boundary creep risk**: avoid pushing business transition rules into LiveView/hook; keep state transitions in `agents` domain/application modules
