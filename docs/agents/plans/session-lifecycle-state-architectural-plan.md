# Feature: Session Lifecycle State (#400)

## App Ownership

| Artifact | Owning App | Repo | Path |
|----------|-----------|------|------|
| Domain entity (Session) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/sessions/domain/entities/session.ex` |
| Domain policy (SessionLifecyclePolicy) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/sessions/domain/policies/session_lifecycle_policy.ex` |
| Domain events | `agents` | `Agents.Repo` | `apps/agents/lib/agents/sessions/domain/events/` |
| Infrastructure schema update | `agents` | `Agents.Repo` | `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex` |
| Migration | `agents` | `Agents.Repo` | `apps/agents/priv/repo/migrations/` |
| LiveView / UI components | `agents_web` | — | `apps/agents_web/lib/live/sessions/` |
| Feature files (BDD) | `agents_web` | — | `apps/agents_web/test/features/sessions/` |
| Unit tests (entity) | `agents` | — | `apps/agents/test/agents/sessions/domain/entities/` |
| Unit tests (policy) | `agents` | — | `apps/agents/test/agents/sessions/domain/policies/` |
| Unit tests (events) | `agents` | — | `apps/agents/test/agents/sessions/domain/events/` |
| Unit tests (state machine) | `agents_web` | — | `apps/agents_web/test/live/sessions/` |

## Overview

The Sessions UI cannot distinguish between a cold-queued task (waiting for a container), a warming task (container spinning up), and a running task (actively executing). Two orthogonal state axes — task status (DB-persisted strings) and container warm state (runtime atoms, never persisted) — are never unified. The `TicketEnrichmentPolicy` collapses 5 distinct active states into a single `"running"` string, destroying granularity.

This plan introduces a `Session` domain entity that unifies these two axes into a single `lifecycle_state` field, a `SessionLifecyclePolicy` that derives and validates state transitions, and the infrastructure/UI updates needed to surface this in the browser.

## UI Strategy

- **LiveView coverage**: 100% — all rendering is server-driven via PubSub
- **TypeScript needed**: P2 only (type export for hooks/channel clients) — not blocking

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/sessions/`
- **Primary context**: `Agents.Sessions`
- **Dependencies**: None (self-contained within `Agents.Sessions`)
- **Exported schemas**: `Session` entity will be exported via the `Agents.Sessions` boundary
- **New context needed?**: No — this belongs squarely within `Agents.Sessions`

## Lifecycle States

The unified lifecycle state set (11 values):

| State | Derivation | Category |
|-------|-----------|----------|
| `idle` | No task, or task status nil | Initial |
| `queued_cold` | status=queued, no real container | Active |
| `queued_warm` | status=queued, real container_id present | Active |
| `warming` | status=pending, container_id present but no port | Active |
| `pending` | status=pending, no container or port present | Active |
| `starting` | status=starting | Active |
| `running` | status=running | Active |
| `awaiting_feedback` | status=awaiting_feedback | Active |
| `completed` | status=completed | Terminal |
| `failed` | status=failed | Terminal |
| `cancelled` | status=cancelled | Terminal |

## Valid Lifecycle Transitions

```
idle → queued_cold
idle → queued_warm
queued_cold → warming
queued_cold → pending
queued_cold → cancelled
queued_warm → pending
queued_warm → starting
queued_warm → cancelled
warming → pending
warming → failed
warming → cancelled
pending → starting
pending → cancelled
starting → running
starting → cancelled
running → completed
running → failed
running → cancelled
running → awaiting_feedback
awaiting_feedback → queued_cold
awaiting_feedback → queued_warm
```

---

## Phase 1: Domain + Application (phoenix-tdd)

### 1.1 Session Domain Entity

⏸ **Status**: Not Started

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/session_test.exs`
  - Tests for `new/1`: creates Session with lifecycle_state, task_id, user_id, container_id, container_port, status fields
  - Tests for `from_task/1`: converts a Task entity (or task-like map) into a Session with derived lifecycle_state
  - Tests for `from_task/2`: converts a Task entity + container metadata map into a Session
  - Default lifecycle_state is `:idle`
  - Valid lifecycle states constant returns all 11 states
  - Test `valid_lifecycle_states/0` returns the exact 11-element list
  - Test `display_name/1` returns human-readable labels: `:queued_cold` → `"Queued (cold)"`, `:queued_warm` → `"Queued (warm)"`, `:warming` → `"Warming up"`, `:starting` → `"Starting"`, `:running` → `"Running"`, `:awaiting_feedback` → `"Awaiting feedback"`, `:completed` → `"Completed"`, `:failed` → `"Failed"`, `:cancelled` → `"Cancelled"`, `:idle` → `"Idle"`, `:pending` → `"Pending"`
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/session.ex`
  - Pure struct with `defstruct` (NO Ecto)
  - Fields: `task_id`, `user_id`, `lifecycle_state`, `status` (original task status), `container_id`, `container_port`, `session_id`, `instruction`, `error`, `queue_position`, `queued_at`, `started_at`, `completed_at`
  - `new/1` — creates from attribute map
  - `from_task/1` — converts Task entity (or map with `:status`, `:container_id`, `:container_port` keys) into Session, calling `SessionLifecyclePolicy.derive/1` for lifecycle_state derivation
  - `from_task/2` — takes task + extra container metadata for runtime enrichment
  - `valid_lifecycle_states/0` — returns the 11 valid states as atoms
  - `display_name/1` — maps lifecycle_state atom to human-readable string
- [ ] **REFACTOR**: Ensure from_task delegates to SessionLifecyclePolicy.derive/1 (not duplicating logic)

### 1.2 SessionLifecyclePolicy — Core Derivation & Transitions

⏸ **Status**: Not Started

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/session_lifecycle_policy_test.exs`
  - **`derive/1` tests** (pure function, takes map with :status, :container_id, :container_port):
    - `nil` status or nil map → `:idle`
    - `"queued"` + no real container → `:queued_cold`
    - `"queued"` + real container_id → `:queued_warm`
    - `"pending"` + real container_id + nil port → `:warming`
    - `"pending"` + no container or both container+port → `:pending`
    - `"starting"` → `:starting`
    - `"running"` → `:running`
    - `"awaiting_feedback"` → `:awaiting_feedback`
    - `"completed"` → `:completed`
    - `"failed"` → `:failed`
    - `"cancelled"` → `:cancelled`
    - Unknown status → `:idle` (defensive)
    - `"queued"` + `"task:placeholder"` container → `:queued_cold` (fake containers are cold)
    - `"queued"` + empty string container → `:queued_cold`
  - **`can_transition?/2` tests**:
    - All valid transitions from the table above return `true`
    - Invalid transitions return `false` (e.g., `:completed` → `:running`, `:idle` → `:running`)
    - Self-transitions return `false` (e.g., `:running` → `:running`)
  - **Predicate tests**:
    - `active?/1`: true for `[:queued_cold, :queued_warm, :warming, :pending, :starting, :running, :awaiting_feedback]`, false for `[:idle, :completed, :failed, :cancelled]`
    - `terminal?/1`: true for `[:completed, :failed, :cancelled]`, false for all others
    - `warm?/1`: true for `[:queued_warm, :warming, :running, :starting]`, false for `[:queued_cold, :idle, :pending, :completed, :failed, :cancelled]`
    - `cold?/1`: true for `[:queued_cold, :idle]`, false for warm/active states
    - `can_submit_message?/1`: true for `[:queued_cold, :queued_warm, :warming, :pending, :starting, :running, :awaiting_feedback]`, false for `[:idle, :completed, :failed, :cancelled]`
  - Use `task/1` helper pattern (default map with overrides) matching existing QueueEngine test pattern
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/session_lifecycle_policy.ex`
  - Module: `Agents.Sessions.Domain.Policies.SessionLifecyclePolicy`
  - `@valid_transitions` — MapSet of `{from_state, to_state}` tuples (atoms)
  - `derive/1` — takes a map with `:status`, `:container_id`, `:container_port` keys, returns lifecycle_state atom. Reuses the `real_container?/1` check logic from QueueEngine.
  - `can_transition?/2` — validates lifecycle transitions between atoms
  - `active?/1`, `terminal?/1`, `warm?/1`, `cold?/1`, `can_submit_message?/1` — predicates on lifecycle_state atom
  - Pure functions only, no I/O
- [ ] **REFACTOR**: Extract `real_container?/1` into a shared private helper or import from QueueEngine if boundary permits. If not, replicate the 3-line check (acceptable duplication for boundary isolation).

### 1.3 Domain Events — SessionStateChanged, SessionWarmingStarted, SessionWarmed

⏸ **Status**: Not Started

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_state_changed_test.exs`
  - Tests: `new/1` with valid attrs (aggregate_id, actor_id, task_id, from_state, to_state, lifecycle_state)
  - Verify `event_type/0` returns `"sessions.session_state_changed"`
  - Verify `aggregate_type/0` returns `"session"`
  - Auto-generates event_id and occurred_at
  - Raises on missing required fields (task_id, from_state, to_state)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_state_changed.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, from_state: nil, to_state: nil, lifecycle_state: nil, container_id: nil], required: [:task_id, :from_state, :to_state]`
- [ ] **REFACTOR**: Ensure event follows existing pattern exactly (see TaskCreated)

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_warming_started_test.exs`
  - Tests: `new/1` with valid attrs (aggregate_id, actor_id, task_id, container_id)
  - Verify `event_type/0` returns `"sessions.session_warming_started"`
  - Verify `aggregate_type/0` returns `"session"`
  - Raises on missing required fields (task_id)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_warming_started.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, container_id: nil], required: [:task_id]`
- [ ] **REFACTOR**: Clean up

- [ ] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_warmed_test.exs`
  - Tests: `new/1` with valid attrs (aggregate_id, actor_id, task_id, container_id, container_port)
  - Verify `event_type/0` returns `"sessions.session_warmed"`
  - Verify `aggregate_type/0` returns `"session"`
  - Raises on missing required fields (task_id)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_warmed.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, container_id: nil, container_port: nil], required: [:task_id]`
- [ ] **REFACTOR**: Clean up

### 1.4 Update TicketEnrichmentPolicy — Replace Lossy Mapping (P0)

⏸ **Status**: Not Started

- [ ] **RED**: Update test `apps/agents/test/agents/sessions/domain/policies/ticket_enrichment_policy_test.exs`
  - Add new tests for lifecycle-state-aware enrichment:
    - Task with status=queued, no container → session_state = `"queued_cold"`
    - Task with status=queued, real container → session_state = `"queued_warm"`
    - Task with status=pending, container but no port → session_state = `"warming"`
    - Task with status=pending, no container → session_state = `"pending"`
    - Task with status=running → session_state = `"running"`
    - Task with status=completed → session_state = `"completed"`
    - Task with status=failed → session_state = `"failed"`
    - Task with status=cancelled → session_state = `"cancelled"`
    - Task with status=awaiting_feedback → session_state = `"awaiting_feedback"`
    - No matching task → session_state = `"idle"`
  - Update existing test expectations: `"running"` status now maps to `"running"` (unchanged), but `"failed"` now maps to `"failed"` instead of `"paused"`
  - Specifically, test that enriched child ticket with status `"failed"` now has session_state `"failed"` (was `"paused"`)
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/policies/ticket_enrichment_policy.ex`
  - Replace `task_status_to_session_state/1` with delegation to `SessionLifecyclePolicy.derive/1`
  - `apply_enrichment/2` builds a map with `:status`, `:container_id`, `:container_port` from the task, calls `SessionLifecyclePolicy.derive/1`, converts result atom to string for `session_state` field
  - The mapping is now: `Atom.to_string(SessionLifecyclePolicy.derive(task_map))`
- [ ] **REFACTOR**: Remove the old `task_status_to_session_state/1` private function entirely. Ensure backward compatibility is maintained in the `apply_enrichment/2` path.

### Phase 1 Validation

- [ ] All entity tests pass: `mix test apps/agents/test/agents/sessions/domain/entities/session_test.exs` (milliseconds, no I/O)
- [ ] All policy tests pass: `mix test apps/agents/test/agents/sessions/domain/policies/session_lifecycle_policy_test.exs` (milliseconds, no I/O)
- [ ] All event tests pass: `mix test apps/agents/test/agents/sessions/domain/events/session_*_test.exs` (milliseconds, no I/O)
- [ ] Updated enrichment tests pass: `mix test apps/agents/test/agents/sessions/domain/policies/ticket_enrichment_policy_test.exs`
- [ ] No boundary violations: `mix boundary` (run from umbrella root)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### 2.1 Migration — Add lifecycle_state Column to sessions_tasks (P1)

⏸ **Status**: Not Started

- [ ] Create migration `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_lifecycle_state_to_sessions_tasks.exs`
  - Module: `Agents.Repo.Migrations.AddLifecycleStateToSessionsTasks`
  - `use Ecto.Migration`
  - `def change do`:
    - `alter table(:sessions_tasks) do add(:lifecycle_state, :string, default: "idle") end`
    - `create index(:sessions_tasks, [:user_id, :lifecycle_state])`
  - Backfill in a separate `execute/2` block:
    - `UPDATE sessions_tasks SET lifecycle_state = CASE WHEN status = 'completed' THEN 'completed' WHEN status = 'failed' THEN 'failed' WHEN status = 'cancelled' THEN 'cancelled' WHEN status = 'running' THEN 'running' WHEN status = 'starting' THEN 'starting' WHEN status = 'awaiting_feedback' THEN 'awaiting_feedback' WHEN status = 'pending' THEN 'pending' WHEN status = 'queued' AND container_id IS NOT NULL AND container_id != '' AND container_id NOT LIKE 'task:%' THEN 'queued_warm' WHEN status = 'queued' THEN 'queued_cold' ELSE 'idle' END WHERE lifecycle_state IS NULL OR lifecycle_state = 'idle'`
    - Rollback: no-op (column drop handles it)

### 2.2 Update TaskSchema — Add lifecycle_state field

⏸ **Status**: Not Started

- [ ] **RED**: Write/update test for schema changeset validation that lifecycle_state is included in cast/validate
  - Test that `status_changeset/2` accepts `:lifecycle_state` in attrs
  - Test that `changeset/2` accepts `:lifecycle_state` in attrs
  - Test that lifecycle_state validates inclusion in valid lifecycle states
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex`
  - Add `field(:lifecycle_state, :string, default: "idle")` to schema block
  - Add `:lifecycle_state` to both `changeset/2` and `status_changeset/2` cast lists
  - Add `validate_inclusion(:lifecycle_state, @valid_lifecycle_states)` where `@valid_lifecycle_states` is `["idle", "queued_cold", "queued_warm", "warming", "pending", "starting", "running", "awaiting_feedback", "completed", "failed", "cancelled"]`
  - Update the `@type t` typespec to include `lifecycle_state: String.t()`
- [ ] **REFACTOR**: Ensure Task entity's `from_schema/1` maps the new `lifecycle_state` field

### 2.3 Update Task Entity — Include lifecycle_state field

⏸ **Status**: Not Started

- [ ] **RED**: Update `apps/agents/test/agents/sessions/domain/entities/task_test.exs`
  - Add test: `from_schema/1` maps `lifecycle_state` from schema
  - Add test: `new/1` accepts `lifecycle_state` field
  - Add test: `lifecycle_state` defaults to `nil` (entity doesn't enforce default; DB/schema does)
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/entities/task.ex`
  - Add `:lifecycle_state` to `@type t`, `defstruct`, and `from_schema/1`
- [ ] **REFACTOR**: Clean up

### 2.4 Update QueueEngine — Delegate to SessionLifecyclePolicy (P1)

⏸ **Status**: Not Started

- [ ] **RED**: Update `apps/agents/test/agents/sessions/domain/policies/queue_engine_test.exs`
  - Existing `classify_warm_state/1` tests should continue passing (backward compatible)
  - Add new test: `classify_warm_state/1` returns same results as before (regression guard)
  - The internal delegation is transparent — tests verify behavior, not implementation
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/policies/queue_engine.ex`
  - `classify_warm_state/1` implementation delegates to `SessionLifecyclePolicy.derive/1` and maps lifecycle_state back to warm_state atoms:
    - `:queued_cold`, `:idle` → `:cold`
    - `:warming` → `:warming`
    - `:queued_warm`, `:pending`, `:starting` → `:warm`
    - `:running` → `:hot`
    - `:completed`, `:failed`, `:cancelled`, `:awaiting_feedback` → `:cold`
  - Keep `classify_warm_state/1` public API signature unchanged for backward compatibility
- [ ] **REFACTOR**: Remove duplicated `real_container?/1` logic if SessionLifecyclePolicy provides equivalent check. Keep QueueEngine's `real_container?/1` if still used elsewhere in the module.

### 2.5 PubSub Integration — Broadcast Lifecycle Transitions (P0)

⏸ **Status**: Not Started

- [ ] **RED**: Add/update integration-style test (if existing task_runner or orchestrator tests exist) verifying that `{:lifecycle_state_changed, task_id, from_state, to_state}` is broadcast on `"task:#{task_id}"` topic
  - Note: Infrastructure PubSub tests may need `Agents.DataCase` rather than pure unit tests
- [ ] **GREEN**: Update broadcast functions in infrastructure:
  - `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`:
    - Update `broadcast_status/3` to also broadcast `{:lifecycle_state_changed, task_id, from_state, to_state}` on `"task:#{task_id}"` topic
    - Compute `from_state` and `to_state` using `SessionLifecyclePolicy.derive/1` (before and after status change)
  - `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex`:
    - Update `broadcast_task_status/3` to also broadcast lifecycle state change
  - `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`:
    - When promoting tasks or changing task state, broadcast lifecycle transitions
- [ ] **REFACTOR**: Extract a shared `broadcast_lifecycle_transition/4` helper to avoid duplication across TaskRunner, QueueManager, QueueOrchestrator

### 2.6 Update SessionStateMachine — Add Warm-State-Aware States (P1)

⏸ **Status**: Not Started

- [ ] **RED**: Update `apps/agents_web/test/live/sessions/session_state_machine_test.exs`
  - **`state_from_task/1` updates**:
    - Add test: task with `lifecycle_state: "queued_cold"` → `:queued_cold`
    - Add test: task with `lifecycle_state: "queued_warm"` → `:queued_warm`
    - Add test: task with `lifecycle_state: "warming"` → `:warming`
    - Add test: falls back to status-based derivation when `lifecycle_state` is nil (backward compat)
  - **New predicate tests**:
    - `warming?/1`: true for `:warming`, false for all others
    - `queued_cold?/1`: true for `:queued_cold`, false for all others
    - `queued_warm?/1`: true for `:queued_warm`, false for all others
    - `task_running?/1`: now includes `:warming` (container spinning up is "running" from user perspective)
  - **Updated `active?/1`**: now includes `:queued_cold`, `:queued_warm`, `:warming`
  - **Updated `can_submit_message?/1`**: includes all new active states
  - **Updated `submission_route/1`**: `:queued_cold`, `:queued_warm`, `:warming` → `:follow_up`
  - **`display_name/1`**: delegates to `Session.display_name/1` for consistent labels
- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/session_state_machine.ex`
  - Add `:queued_cold`, `:queued_warm`, `:warming` to `@type state`
  - Update `@status_to_state` to include `"queued_cold" => :queued_cold`, `"queued_warm" => :queued_warm`, `"warming" => :warming`
  - Update `state_from_task/1` to prefer `lifecycle_state` field when present (non-nil), falling back to `status`-based mapping
  - Add `@running_states` to include `:warming` (user sees it as "task is being prepared")
  - Add `@active_states` to include `:queued_cold, :queued_warm, :warming`
  - Add predicate functions: `warming?/1`, `queued_cold?/1`, `queued_warm?/1`
  - Add `display_name/1` delegating to `Agents.Sessions.Domain.Entities.Session.display_name/1`
- [ ] **REFACTOR**: Ensure all existing tests still pass (backward compat)

### 2.7 Update Helpers — Lifecycle-Aware CSS Classes (P1)

⏸ **Status**: Not Started

- [ ] **RED**: Add tests for new lifecycle state CSS classes (if helpers have tests)
  - `ticket_session_state_class("queued_cold")` → appropriate class
  - `ticket_session_state_class("queued_warm")` → appropriate class
  - `ticket_session_state_class("warming")` → appropriate class
  - `ticket_session_state_class("awaiting_feedback")` → appropriate class
  - `ticket_session_state_class("failed")` → `"badge-error"` (was `"paused"` → `"badge-warning"`)
  - `ticket_session_state_class("cancelled")` → `"badge-warning"`
- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/helpers.ex`
  - Update `ticket_session_state_class/1` to handle all 11 lifecycle states:
    - `"running"` → `"badge-success"`
    - `"queued_cold"` → `"badge-info"`
    - `"queued_warm"` → `"badge-info"`
    - `"warming"` → `"badge-warning"`
    - `"pending"` → `"badge-info"`
    - `"starting"` → `"badge-info"`
    - `"awaiting_feedback"` → `"badge-warning"`
    - `"completed"` → `"badge-primary"`
    - `"failed"` → `"badge-error"`
    - `"cancelled"` → `"badge-ghost"`
    - `"idle"` or other → `"badge-ghost"`
- [ ] **REFACTOR**: Remove old `"paused"` mapping (no longer exists in lifecycle states)

### 2.8 Update Queue Lane Components — Lifecycle-Aware Indicators (P1)

⏸ **Status**: Not Started

- [ ] **RED**: Verify existing warm_state_indicator tests/expectations still hold
  - The BDD feature file expects:
    - `[data-testid='warm-state-indicator-cold']` inside `[data-testid='lane-cold']`
    - `[data-testid='warm-state-indicator-warming']` inside `[data-testid='lane-warming']`
    - `[data-testid='warm-state-indicator-warm']` inside `[data-testid='lane-warm']`
- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/components/queue_lane_components.ex`
  - Update `warm_state_indicator/1` data-testid values to match BDD expectations:
    - `:cold` → `data-testid="warm-state-indicator-cold"`
    - `:warming` → `data-testid="warm-state-indicator-warming"`
    - `:warm` → `data-testid="warm-state-indicator-warm"`
    - `:hot` / `:processing` → `data-testid="warm-state-indicator-hot"`
  - Ensure lane data-testid pattern supports the BDD `[data-testid='lane-warming']` expectation (may need a `:warming` lane or render warming entries within their lane with correct data-testid)
- [ ] **REFACTOR**: Clean up

### 2.9 LiveView — Lifecycle State Display in Session Cards (P0)

⏸ **Status**: Not Started

- [ ] **RED**: Write/update LiveView tests for lifecycle state rendering
  - The BDD feature file expects:
    - `[data-testid='session-task-card']` containing `[data-testid='lifecycle-state']` with text matching display names
    - `[data-testid='session-task-card'][data-task-id='...']` for transition scenarios
    - `[data-testid='triage-ticket-item']` containing `[data-testid='ticket-lifecycle-state']` for ticket view
    - `[data-testid='state-predicate-active']` visible for active states
    - `[data-testid='state-predicate-terminal']` absent for active states
  - Test that `handle_info({:lifecycle_state_changed, task_id, from, to}, socket)` updates the rendered lifecycle state
- [ ] **GREEN**: Update LiveView templates in `apps/agents_web/lib/live/sessions/`:
  - Add `data-testid="lifecycle-state"` element to session task cards displaying `Session.display_name(lifecycle_state)`
  - Add `data-testid="ticket-lifecycle-state"` element to triage ticket items
  - Add `data-testid="state-predicate-active"` conditional element (visible when `SessionStateMachine.active?/1`)
  - Add `data-testid="state-predicate-terminal"` conditional element (visible when `SessionStateMachine.terminal?/1`)
  - Add `data-task-id` attribute to session-task-card elements
  - Handle `{:lifecycle_state_changed, task_id, from_state, to_state}` in `handle_info/2`
  - Subscribe to `task:#{task_id}` topic for lifecycle events (existing subscription pattern)
- [ ] **REFACTOR**: Keep LiveView thin — delegate all state derivation to SessionStateMachine and Session entity

### 2.10 LiveView — Real-time Transition Handling (P0)

⏸ **Status**: Not Started

- [ ] **RED**: Write LiveView test verifying that sending a lifecycle_state_changed message to the view process updates the rendered state
  - Test: `send(view.pid, {:lifecycle_state_changed, task_id, :queued_cold, :warming})` → lifecycle-state text changes to "Warming up"
  - Test: rapid transitions (:warming → :starting → :running) each update the displayed state
- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex` (or appropriate LiveView module)
  - Add `handle_info({:lifecycle_state_changed, task_id, from_state, to_state}, socket)` clause
  - Update the relevant task's `lifecycle_state` in socket assigns/streams
  - The UI re-renders with the new `Session.display_name(to_state)`
- [ ] **REFACTOR**: Ensure no duplicate handling between `:task_status_changed` and `:lifecycle_state_changed` — lifecycle state change should be the primary, with task_status_changed handled for backward compatibility during migration

### 2.11 Observability — Debug Logging for Lifecycle Transitions (P2)

⏸ **Status**: Not Started

- [ ] **RED**: Verify Logger.debug call is made with structured metadata when lifecycle transitions occur
- [ ] **GREEN**: Add `Logger.debug` calls at lifecycle transition broadcast points in TaskRunner/QueueOrchestrator/QueueManager:
  - `Logger.debug("Session lifecycle transition", task_id: task_id, from_state: from_state, to_state: to_state, container_id: container_id)`
- [ ] **REFACTOR**: Clean up

### Phase 2 Validation

- [ ] All infrastructure tests pass
- [ ] All interface tests pass (SessionStateMachine, LiveView)
- [ ] Migration runs cleanly: `mix ecto.migrate` (in agents app)
- [ ] Backfill populates lifecycle_state for existing tasks
- [ ] No boundary violations: `mix boundary`
- [ ] Full test suite passes: `mix test` (umbrella-wide)
- [ ] BDD feature file scenarios verifiable against the new data-testid attributes

### Pre-commit Checkpoint

- [ ] `mix precommit` passes (compile with warnings-as-errors, boundary, format, credo, tests)

---

## Phase 3: TypeScript (OPTIONAL, P2)

### 3.1 Export Lifecycle State Type

⏸ **Status**: Not Started

**Justification**: LiveView hooks and channel clients in TypeScript need to pattern-match on lifecycle_state values. Without a shared type, TypeScript code uses raw strings with no compile-time safety.

- [ ] **RED**: Write Vitest test verifying the type definition exports all 11 lifecycle states
- [ ] **GREEN**: Create TypeScript type at `apps/agents_web/assets/js/types/session-lifecycle.ts`:
  ```typescript
  export type SessionLifecycleState =
    | "idle" | "queued_cold" | "queued_warm" | "warming"
    | "pending" | "starting" | "running" | "awaiting_feedback"
    | "completed" | "failed" | "cancelled";

  export const ACTIVE_STATES: SessionLifecycleState[] = [
    "queued_cold", "queued_warm", "warming", "pending",
    "starting", "running", "awaiting_feedback"
  ];

  export const TERMINAL_STATES: SessionLifecycleState[] = [
    "completed", "failed", "cancelled"
  ];

  export function displayName(state: SessionLifecycleState): string { ... }
  ```
- [ ] **REFACTOR**: Ensure hook files import from this shared type

---

## Testing Strategy

### Test Distribution

| Layer | Test File | Count (est.) | Async | DB? |
|-------|-----------|-------------|-------|-----|
| Entity | `session_test.exs` | 10-12 | ✓ | ✗ |
| Policy | `session_lifecycle_policy_test.exs` | 35-40 | ✓ | ✗ |
| Events | `session_state_changed_test.exs` | 6-8 | ✓ | ✗ |
| Events | `session_warming_started_test.exs` | 5-6 | ✓ | ✗ |
| Events | `session_warmed_test.exs` | 5-6 | ✓ | ✗ |
| Policy (update) | `ticket_enrichment_policy_test.exs` | 8-10 new | ✓ | ✗ |
| Policy (update) | `queue_engine_test.exs` | 2-3 new | ✓ | ✗ |
| State machine (update) | `session_state_machine_test.exs` | 15-20 new | ✓ | ✗ |
| LiveView | LiveView lifecycle display tests | 8-10 | ✗ | ✓ |
| BDD | `session-lifecycle-state.browser.feature` | 15 scenarios | — | — |

**Total estimated**: ~110-125 tests (pure function tests: ~85, integration: ~15, BDD: ~15)

### BDD Scenario Coverage Mapping

Each BDD scenario maps to implementation steps:

| BDD Scenario | Implementation Step(s) |
|---|---|
| Unauthenticated redirect | Existing auth — no changes |
| Login and access | Existing auth — no changes |
| Invalid credentials error | Existing auth — no changes |
| Cold-queued shows "Queued (cold)" | 1.1 (display_name), 1.2 (derive), 2.6 (state machine), 2.9 (LiveView) |
| Warm-queued shows "Queued (warm)" | 1.1, 1.2, 2.6, 2.9 |
| Warming shows "Warming up" | 1.1, 1.2, 2.6, 2.9 |
| Starting shows "Starting" | 1.1, 2.6, 2.9 |
| Running shows "Running" | 1.1, 2.6, 2.9 |
| Awaiting feedback shows "Awaiting feedback" | 1.1, 2.6, 2.9 |
| Completed shows "Completed" | 1.1, 2.6, 2.9 |
| Failed shows "Failed" | 1.1, 2.6, 2.9 |
| Cancelled shows "Cancelled" | 1.1, 2.6, 2.9 |
| Real-time cold→warming transition | 1.2, 1.3, 2.5, 2.10 |
| Real-time warming→starting→running | 1.2, 1.3, 2.5, 2.10 |
| Warm fast path (skips warming) | 1.2, 2.5, 2.10 |
| State machine predicates visible | 2.6, 2.9 |
| Ticket carries full lifecycle state | 1.4, 2.9 |
| Queue lane lifecycle indicators | 2.8 |

### Key Test Principles

1. **Domain/Policy tests are pure** — `use ExUnit.Case, async: true`, no DB, run in milliseconds
2. **Entity tests follow existing pattern** — test `new/1`, `from_task/1`, field defaults, display names
3. **Policy tests use helper function** — `defp task(overrides)` merges into default map (see QueueEngineTest)
4. **Event tests follow existing pattern** — test `new/1` with `@valid_attrs`, verify event_type/aggregate_type, auto-generated fields, required field validation
5. **State machine tests are exhaustive** — test every state for every predicate
6. **LiveView tests use `send/2`** — send lifecycle_state_changed messages to view process, assert render changes
7. **Backward compatibility** — all existing tests must continue to pass unchanged (or with minimal, documented updates)

---

## Implementation Order Summary

```
Phase 1 (Domain — pure functions, no I/O):
  1.1 Session entity           ← foundation for everything
  1.2 SessionLifecyclePolicy   ← core derivation + transitions
  1.3 Domain events            ← SessionStateChanged, SessionWarmingStarted, SessionWarmed
  1.4 TicketEnrichmentPolicy   ← replace lossy mapping

Phase 2 (Infrastructure + Interface):
  2.1 Migration                ← DB column
  2.2 TaskSchema update        ← lifecycle_state field in Ecto
  2.3 Task entity update       ← lifecycle_state in domain struct
  2.4 QueueEngine delegation   ← backward-compatible bridge
  2.5 PubSub integration       ← broadcast lifecycle transitions
  2.6 SessionStateMachine      ← UI state machine with new states
  2.7 Helpers CSS classes      ← lifecycle-aware styling
  2.8 Queue lane components    ← updated data-testid attributes
  2.9 LiveView display         ← render lifecycle state in cards
  2.10 LiveView transitions    ← real-time PubSub handling
  2.11 Observability           ← debug logging

Phase 3 (TypeScript — optional P2):
  3.1 Type export              ← SessionLifecycleState type
```

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Existing tests break when TicketEnrichmentPolicy changes | Medium | Update test expectations for `"paused"` → `"failed"` / `"cancelled"` mapping change. Run full suite after each step. |
| QueueEngine.classify_warm_state delegation changes behavior | Medium | Run existing QueueEngine tests as regression guard before and after delegation. |
| Backfill migration is slow on large tables | Low | Use single SQL UPDATE (no row-by-row loop). Index creation is concurrent-safe. |
| BDD fixtures for lifecycle states don't exist yet | High | LiveView must support `?fixture=session_lifecycle_*` query params to seed test data. This is a common pattern — implement fixture handling in the LiveView mount. |
| Two parallel queue systems (QueueManager + QueueOrchestrator) | Medium | Update BOTH per design decision. Integration tested via existing infrastructure tests. |

## Dependencies

- **Blocks**: #309 (priority-ordered layout) depends on this ticket's lifecycle states
- **Blocked by**: Nothing — can start immediately
- **Related**: #392 (restructure sessions) — separate scope, but lifecycle_state column placement is compatible
