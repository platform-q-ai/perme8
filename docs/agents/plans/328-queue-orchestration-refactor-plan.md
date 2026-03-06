# Feature: #328 — Queue Orchestration Refactor: Rule-Based Session Lifecycle and Reactive UI

## Overview

Refactor the queue orchestration system from an ad-hoc, mixed-responsibility architecture
(650-line QueueManager GenServer + 2031-line LiveView doing inline lane inference) into a
rule-based, layered system where:

1. **QueueEngine** (domain policy) is the single source of truth for lane assignment, transitions, and limits
2. **QueueOrchestrator** (application layer) replaces QueueManager as the per-user process
3. **QueueSnapshot** (domain entity) is the canonical contract between orchestrator and UI
4. **RetryPolicy** (domain policy) defines explicit retry/backoff/escalation rules
5. **UI** becomes a pure reactive projection of snapshots — no lane inference

The refactor is gated by a feature flag for safe rollout, with the legacy QueueManager
running in parallel during migration.

## UI Strategy

- **LiveView coverage**: 100% — all UI changes are template/component simplification
- **TypeScript needed**: None — existing hooks (session-optimistic-state-hook, concurrency-limit-hook,
  warm-cache-limit-hook) will be updated but not fundamentally changed

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/`
- **Primary context**: `Agents.Sessions`
- **Dependencies**: `identity` (auth), `perme8_events` (event infrastructure)
- **Exported schemas**: `Agents.Sessions.Domain.Entities.Task` (already exported), new: `Agents.Sessions.Domain.Entities.QueueSnapshot`
- **New context needed?**: No — this is a refactor within the existing `Sessions` context

## Design Decisions

### 1. QueueSnapshot Struct Shape (New Contract Boundary)

```elixir
%QueueSnapshot{
  user_id: String.t(),
  lanes: %{
    processing: [LaneEntry.t()],
    warm: [LaneEntry.t()],
    cold: [LaneEntry.t()],
    awaiting_feedback: [LaneEntry.t()],
    retry_pending: [LaneEntry.t()]
  },
  metadata: %{
    concurrency_limit: non_neg_integer(),
    warm_cache_limit: non_neg_integer(),
    running_count: non_neg_integer(),
    available_slots: non_neg_integer(),
    total_queued: non_neg_integer()
  },
  generated_at: DateTime.t()
}
```

Where `LaneEntry` contains:
```elixir
%LaneEntry{
  task_id: String.t(),
  instruction: String.t(),
  status: String.t(),
  lane: atom(),
  container_id: String.t() | nil,
  warm_state: :cold | :warming | :warm | :hot,
  queue_position: non_neg_integer() | nil,
  retry_count: non_neg_integer(),
  error: String.t() | nil,
  queued_at: DateTime.t() | nil,
  started_at: DateTime.t() | nil
}
```

### 2. Lane Assignment: Pure Domain Policy

Lanes are derived from task status + metadata (no new DB column needed):

| Status | Container State | → Lane |
|--------|----------------|--------|
| `pending`, `starting`, `running` | — | `processing` |
| `queued` | warm/hot | `warm` |
| `queued` | cold/nil | `cold` |
| `awaiting_feedback` | — | `awaiting_feedback` |
| `queued` + retry_count > 0 | — | `retry_pending` |
| `completed`, `failed`, `cancelled` | — | (not in snapshot — terminal) |

### 3. Retry Strategy

- Max retries: 3 (configurable per-user)
- Backoff: exponential (base 5s: 5s, 25s, 125s)
- Retryable: runner start failures, container crashes. NOT: user cancellation, validation errors.
- After max retries: move to `failed` with `retry_exhausted` error

### 4. Migration Strategy

- Add `retry_count` and `last_retry_at` columns to `sessions_tasks`
- No `lane` column — lanes are derived at runtime by `QueueEngine`
- Feature flag: `queue_orchestrator_v2` (checked in Sessions facade)

### 5. Feature Flag Strategy

- `Agents.Sessions.Application.SessionsConfig.queue_v2_enabled?()` — reads from app config
- Sessions facade checks flag to route to QueueManager (legacy) or QueueOrchestrator (new)
- LiveView subscribes to same PubSub topic regardless — snapshot shape is normalized at broadcast

---

## Phase 1: Domain Layer — QueueEngine + QueueSnapshot + RetryPolicy ✓

**Goal**: Pure domain models and policies. No I/O, no infrastructure. All tests run async in milliseconds.

**Commit point**: "feat(agents): add queue engine, snapshot, lane entry, and retry policy domain models"

### Step 1.1: QueueSnapshot + LaneEntry Entities

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/queue_snapshot_test.exs`
  - Tests:
    - `QueueSnapshot.new/1` creates a valid snapshot with all lanes defaulting to empty lists
    - `QueueSnapshot.total_queued/1` returns sum of warm + cold + retry_pending lane sizes
    - `QueueSnapshot.available_slots/1` computes `concurrency_limit - running_count`
    - `QueueSnapshot.lane_for/2` returns the lane list for a given lane atom
    - `LaneEntry.new/1` creates a valid lane entry with defaults
    - `LaneEntry.warm?/1`, `LaneEntry.cold?/1` predicates work based on `warm_state`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/queue_snapshot.ex`
  - Pure struct with `new/1`, `total_queued/1`, `available_slots/1`, `lane_for/2`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/lane_entry.ex`
  - Pure struct with `new/1`, `warm?/1`, `cold?/1` predicates
- [x] **REFACTOR**: Extract shared types, ensure consistent naming

### Step 1.2: QueueEngine Policy (Lane Assignment + Transitions)

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/queue_engine_test.exs`
  - Tests:
    - `assign_lane/1` returns `:processing` for pending/starting/running tasks
    - `assign_lane/1` returns `:warm` for queued tasks with a real container_id
    - `assign_lane/1` returns `:cold` for queued tasks with nil or placeholder container_id
    - `assign_lane/1` returns `:awaiting_feedback` for awaiting_feedback tasks
    - `assign_lane/1` returns `:retry_pending` for queued tasks with retry_count > 0
    - `assign_lane/1` returns `:terminal` for completed/failed/cancelled tasks
    - `build_snapshot/2` builds a full QueueSnapshot from a list of tasks and config map
    - `build_snapshot/2` sorts processing lane by started_at
    - `build_snapshot/2` sorts warm/cold lanes by queue_position ascending
    - `build_snapshot/2` populates metadata correctly (running_count, available_slots, etc.)
    - `can_transition?/2` validates allowed state transitions (queued→pending, pending→running, etc.)
    - `can_transition?/2` rejects invalid transitions (completed→running, cancelled→pending, etc.)
    - `promotable_tasks/1` returns cold/warm tasks sorted by queue_position, warm first
    - `tasks_to_promote/2` returns up to N promotable tasks based on available slots
    - `classify_warm_state/1` returns :cold, :warming, :warm, or :hot based on container metadata
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/queue_engine.ex`
  - Pure functions: `assign_lane/1`, `build_snapshot/2`, `can_transition?/2`, `promotable_tasks/1`, `tasks_to_promote/2`, `classify_warm_state/1`
- [x] **REFACTOR**: Ensure QueueEngine is composable and each function is single-responsibility

### Step 1.3: RetryPolicy (Retry/Backoff/Escalation)

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/retry_policy_test.exs`
  - Tests:
    - `retryable?/1` returns true for runner_start_failed, container_crashed errors
    - `retryable?/1` returns false for user_cancelled, validation_error
    - `retryable?/1` returns false when retry_count >= max_retries
    - `next_retry_delay/1` returns exponential backoff (5s, 25s, 125s)
    - `next_retry_delay/1` caps at maximum delay (10 minutes)
    - `should_escalate?/1` returns true when retry_count >= max_retries
    - `classify_failure/1` classifies error strings into retryable/permanent categories
    - `max_retries/0` returns the configurable default (3)
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/retry_policy.ex`
  - Pure functions: `retryable?/1`, `next_retry_delay/1`, `should_escalate?/1`, `classify_failure/1`, `max_retries/0`
- [x] **REFACTOR**: Clean up, add @spec and @doc annotations

### Step 1.4: Update Existing QueuePolicy

- [x] **RED**: Update test `apps/agents/test/agents/sessions/domain/policies/queue_policy_test.exs`
  - Tests:
    - Existing 8 tests still pass (no regressions)
    - Add `QueuePolicy.valid_concurrency_limit?/1` — true for 1..10
    - Add `QueuePolicy.valid_warm_cache_limit?/1` — true for 0..5
- [x] **GREEN**: Add new functions to `apps/agents/lib/agents/sessions/domain/policies/queue_policy.ex`
- [x] **REFACTOR**: Move limit validation from QueueManager guards into QueuePolicy

### Step 1.5: New Domain Events

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/queue_events_test.exs`
  - Tests:
    - `TaskLaneChanged.new/1` creates valid event with required fields (task_id, user_id, from_lane, to_lane)
    - `TaskRetryScheduled.new/1` creates valid event with required fields (task_id, user_id, retry_count, next_retry_at)
    - `QueueSnapshotUpdated.new/1` creates valid event with required fields (user_id, snapshot)
- [x] **GREEN**: Implement:
  - `apps/agents/lib/agents/sessions/domain/events/task_lane_changed.ex`
  - `apps/agents/lib/agents/sessions/domain/events/task_retry_scheduled.ex`
  - `apps/agents/lib/agents/sessions/domain/events/queue_snapshot_updated.ex`
- [x] **REFACTOR**: Verify event naming consistency with existing events

### Phase 1 Validation

- [x] All domain tests pass (`mix test apps/agents/test/agents/sessions/domain/ --trace`)
- [x] All tests are async (no database access)
- [x] No boundary violations (`mix boundary`)
- [x] Existing QueuePolicy tests still pass (regression check)

---

## Phase 2: Application Layer — QueueOrchestrator Use Cases ⏳

**Goal**: Orchestration logic with mocked dependencies. Feature-flagged alongside legacy QueueManager.

**Commit point**: "feat(agents): add queue orchestrator application layer with feature flag"

### Step 2.1: Feature Flag in SessionsConfig

- ✓ **RED**: Write test `apps/agents/test/agents/sessions/application/sessions_config_test.exs`
  - Tests:
    - `SessionsConfig.queue_v2_enabled?/0` reads from application config
    - Returns false by default
- ✓ **GREEN**: Add `queue_v2_enabled?/0` to `apps/agents/lib/agents/sessions/application/sessions_config.ex`
  - Reads `Application.get_env(:agents, :queue_v2_enabled, false)`
- ✓ **REFACTOR**: Clean up

### Step 2.2: QueueOrchestrator Behaviour

- ⏸ **RED**: Write test verifying the behaviour module defines the expected callbacks
- ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/behaviours/queue_orchestrator_behaviour.ex`
  - Callbacks:
    - `get_snapshot(user_id) :: QueueSnapshot.t()`
    - `notify_task_event(user_id, task_id, event_type) :: :ok`
    - `set_concurrency_limit(user_id, limit) :: :ok | {:error, term()}`
    - `set_warm_cache_limit(user_id, limit) :: :ok | {:error, term()}`
    - `check_concurrency(user_id) :: :ok | :at_limit`
- ✓ **REFACTOR**: Ensure behaviour is minimal and focused

### Step 2.3: BuildSnapshot Use Case

- ✓ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/build_snapshot_test.exs`
  - Tests (using Mox for task_repo):
    - Loads all active tasks for user from repo
    - Delegates to QueueEngine.build_snapshot/2 for lane assignment
    - Returns a valid QueueSnapshot struct
    - Handles empty task list gracefully
    - Populates metadata from SessionsConfig defaults
- ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/build_snapshot.ex`
  - `execute(user_id, opts)` — loads tasks, builds snapshot via QueueEngine
- ✓ **REFACTOR**: Ensure dependency injection for task_repo, config

### Step 2.4: PromoteTask Use Case (Refactored)

- ✓ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/promote_task_test.exs`
  - Tests (using Mox):
    - Only promotes tasks that QueueEngine.can_transition?(task, :pending) returns true for
    - Warm tasks are promoted before cold tasks
    - Promotes up to available_slots count
    - Emits TaskPromoted event for each promoted task
    - Emits TaskLaneChanged event (from_lane: :warm/:cold, to_lane: :processing)
    - Does not promote cold tasks unless warm-ready (consistent with current behavior)
    - Returns updated snapshot after promotion
- ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/promote_task.ex`
  - Uses QueueEngine for policy decisions, delegates I/O to injected repo
- ✓ **REFACTOR**: Compare with existing QueueManager.promote_next_task and ensure parity

### Step 2.5: ScheduleRetry Use Case

- ✓ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/schedule_retry_test.exs`
  - Tests (using Mox):
    - Only retries tasks where RetryPolicy.retryable?/1 returns true
    - Increments retry_count on the task
    - Calculates next_retry_at from RetryPolicy.next_retry_delay/1
    - Emits TaskRetryScheduled event
    - Moves task to retry_pending lane via TaskLaneChanged event
    - When retry_count >= max_retries, marks task as permanently failed
    - Does not retry user-cancelled tasks
- ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/use_cases/schedule_retry.ex`
- ✓ **REFACTOR**: Ensure error classification is thorough

### Step 2.6: Update CreateTask + ResumeTask Use Cases

- ⏸ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs`
  - Tests:
    - Existing tests still pass (regression)
    - When queue_v2_enabled?, task creation emits QueueSnapshotUpdated event
    - Task is assigned to correct lane via QueueEngine after creation
- ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`
  - Add optional snapshot broadcast after task creation (gated by flag)
- ⏸ **RED**: Update test for ResumeTask similarly
- ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex`
- ⏸ **REFACTOR**: Factor out common snapshot-broadcast logic

### Phase 2 Validation

- ✓ All application tests pass with mocks
- ✓ All domain tests still pass (regression)
- ✓ No boundary violations (`mix boundary`)
- ✓ Feature flag defaults to false — no behavioral change in production

---

## Phase 3: Infrastructure Layer — QueueOrchestrator GenServer + Migration ⏳

**Goal**: Replace QueueManager with QueueOrchestrator behind feature flag. Add retry columns.

**Commit point**: "feat(agents): add queue orchestrator GenServer and retry migration"

### Step 3.1: Database Migration

- [x] Create `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_retry_fields_to_sessions_tasks.exs`
  - Add columns:
    - `retry_count :integer, default: 0, null: false`
    - `last_retry_at :utc_datetime, null: true`
    - `next_retry_at :utc_datetime, null: true`
  - Add index: `index(:sessions_tasks, [:user_id, :next_retry_at], where: "status = 'queued' AND retry_count > 0")`

### Step 3.2: Update TaskSchema + Task Entity

- [x] **RED**: Update test `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_test.exs`
  - Tests:
    - Changeset accepts retry_count, last_retry_at, next_retry_at fields
    - retry_count defaults to 0
    - status_changeset allows updating retry fields
- [x] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex`
  - Add fields: `retry_count`, `last_retry_at`, `next_retry_at`
  - Update changeset and status_changeset to cast new fields
- [x] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/entities/task.ex`
  - Add fields: `retry_count`, `last_retry_at`, `next_retry_at` to struct and typespec
  - Update `from_schema/1` to include new fields
  - Update `valid_statuses/0` — no change needed (statuses unchanged)
- [x] **REFACTOR**: Clean up

### Step 3.3: Update TaskRepository + TaskQueries

- ⏸ **RED**: Update/add tests in `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs`
  - Tests:
    - `list_retry_pending_tasks/1` returns queued tasks with retry_count > 0 and next_retry_at <= now
    - `count_active_tasks/1` returns count of pending + starting + running tasks
- ⏸ **GREEN**: Add queries to `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex`
  - `retry_pending_for_user/1` — queued tasks with retry_count > 0, ordered by next_retry_at
  - `active_for_user/1` — pending + starting + running tasks
- ⏸ **GREEN**: Add repository methods to `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex`
  - `list_retry_pending_tasks/1`, `count_active_tasks/1`
- ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex`
  - Add new callback signatures
- ⏸ **REFACTOR**: Ensure query composability

### Step 3.4: QueueOrchestrator GenServer

- [x] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - Tests (integration with real DB, mirrors existing queue_manager_test.exs structure):
    - `get_snapshot/1` returns a valid QueueSnapshot with correct lane assignments
    - `notify_task_completed/2` promotes next queued task and broadcasts snapshot
    - `notify_task_failed/2` checks RetryPolicy, schedules retry or promotes
    - `notify_task_cancelled/2` promotes next queued task
    - `notify_question_asked/2` moves task to awaiting_feedback lane, promotes
    - `notify_feedback_provided/2` requeues task, promotes if capacity
    - `notify_task_queued/2` triggers warmup and promotion
    - `set_concurrency_limit/2` validates via QueuePolicy, enforces limits, broadcasts
    - `set_warm_cache_limit/2` validates, triggers warmup, broadcasts
    - `check_concurrency/1` delegates to QueueEngine via snapshot
    - Broadcasts `{:queue_snapshot, user_id, %QueueSnapshot{}}` on every state change
    - Retry: failed task with retryable error gets retry_count incremented and re-queued after delay
    - Retry: non-retryable failure stays in failed status
    - Retry: exhausted retries stays in failed status with retry_exhausted error
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`
  - GenServer using same Registry/via_tuple pattern as QueueManager
  - Delegates policy decisions to QueueEngine, RetryPolicy, QueuePolicy
  - Broadcasts QueueSnapshot (not raw map) on state changes
  - Handles retry scheduling via `Process.send_after/3`
- [x] **REFACTOR**: Compare with QueueManager for feature parity, remove dead code

### Step 3.5: QueueOrchestrator Supervisor

- [x] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_supervisor_test.exs`
  - Tests:
    - `ensure_started/2` starts an orchestrator for a user
    - `ensure_started/2` returns existing pid if already running
    - Multiple users get separate orchestrator processes
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator_supervisor.ex`
  - DynamicSupervisor, same pattern as QueueManagerSupervisor
- [x] **REFACTOR**: Ensure same fault tolerance guarantees as QueueManagerSupervisor

### Step 3.6: Update Sessions Facade (Feature Flag Routing)

- [x] **RED**: Update test `apps/agents/test/agents/sessions_test.exs`
  - Tests:
    - When `queue_v2_enabled?` is false, all queue functions route to QueueManager (existing behavior)
    - When `queue_v2_enabled?` is true, `get_queue_state/1` returns a QueueSnapshot
    - When `queue_v2_enabled?` is true, `notify_task_terminal_status/4` routes to QueueOrchestrator
    - When `queue_v2_enabled?` is true, `set_concurrency_limit/2` routes to QueueOrchestrator
    - Backward compatibility: QueueSnapshot can be converted to legacy map format
- [x] **GREEN**: Update `apps/agents/lib/agents/sessions.ex`
  - Add private helper `queue_backend/0` that returns `QueueManager` or `QueueOrchestrator`
  - Route queue-related functions through `queue_backend/0`
  - Add `QueueSnapshot.to_legacy_map/1` for backward compatibility during migration
- [x] **REFACTOR**: Remove duplication between legacy and new paths

### Phase 3 Validation

- ⏸ All infrastructure tests pass (with database)
- ⏸ All application + domain tests still pass
- ⏸ Migration runs successfully (`mix ecto.migrate` in agents app)
- ⏸ No boundary violations (`mix boundary`)
- ⏸ Feature flag off: existing QueueManager tests still pass — zero regression
- ⏸ Feature flag on: QueueOrchestrator tests pass with equivalent coverage

---

## Phase 4: Interface Layer — Reactive Snapshot UI ⏳

**Goal**: LiveView subscribes to QueueSnapshot, renders lanes bottom-up. No lane inference in template.

**Commit point**: "feat(agents_web): reactive queue UI driven by QueueSnapshot"

### Step 4.1: QueueSnapshot-Aware Components

- [x] **RED**: Write test `apps/agents_web/test/live/sessions/components/queue_lane_components_test.exs`
  - Tests (using `render_component/2`):
    - `<.queue_lanes>` renders processing lane at bottom, warm above, cold above warm
    - `<.queue_lanes>` shows correct count badges per lane
    - `<.lane_entry>` renders task card with warm/cold/warming indicator
    - `<.lane_entry>` shows retry badge when retry_count > 0
    - `<.queue_metadata>` renders concurrency limit, warm cache limit, available slots from snapshot
    - Empty lanes show appropriate empty states
- [x] **GREEN**: Implement `apps/agents_web/lib/live/sessions/components/queue_lane_components.ex`
  - Function components: `queue_lanes/1`, `lane_entry/1`, `queue_metadata/1`
  - Receives `@snapshot` assign (QueueSnapshot struct)
  - Bottom-up rendering: processing at bottom, warm/cold above, feedback/retry at top
- ⏸ **REFACTOR**: Extract common patterns from existing session_components.ex

### Step 4.2: Update LiveView to Subscribe to Snapshots

- ⏸ **RED**: Update test `apps/agents_web/test/live/sessions/index_test.exs`
  - Tests:
    - (Feature flag on) LiveView assigns `queue_snapshot` from QueueSnapshot struct
    - (Feature flag on) `handle_info({:queue_snapshot, user_id, snapshot})` updates assigns
    - (Feature flag off) LiveView continues to use legacy `queue_state` map
    - Processing sessions appear at bottom of sidebar queue section
    - Warm sessions appear above processing with warm indicator
    - Cold sessions appear above warm
    - Concurrency limit and warm cache limit are rendered from snapshot metadata
    - `derive_sticky_warm_task_ids` is NOT called when v2 is enabled (snapshot provides warm state)
- ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`
  - Add `handle_info({:queue_snapshot, user_id, %QueueSnapshot{}}, socket)` clause
  - When v2 enabled: store snapshot in `@queue_snapshot`, skip `@sticky_warm_task_ids` derivation
  - When v2 disabled: continue existing behavior unchanged
  - Replace ~15 `derive_sticky_warm_task_ids` call sites with snapshot lookup
- ⏸ **REFACTOR**: Remove dead `derive_sticky_warm_task_ids` calls behind feature flag

### Step 4.3: Simplify Template (Feature-Flagged)

- ⏸ **RED**: Update LiveView tests to verify simplified template rendering
  - Tests:
    - (v2) Sidebar renders `<.queue_lanes snapshot={@queue_snapshot}>` instead of inline partitions
    - (v2) No more inline `<% warm_primary_sessions = ... %>` computations in template
    - (v2) Queue panel shows snapshot metadata, not ad-hoc calculations
    - (v1) Template still works with legacy assigns
- ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.html.heex`
  - Behind `if @queue_v2_enabled` conditional:
    - Replace 6+ inline session partition blocks with single `<.queue_lanes>` call
    - Replace warm/cold/overflow/optimistic queue sections with snapshot-driven rendering
    - Remove `warm_candidate_ids`, `warm_primary_sessions`, `overflow_queued_sessions` inline computations
  - Keep legacy block for feature flag off
- ⏸ **REFACTOR**: Remove redundant assigns from mount/handle_params when v2 enabled

### Step 4.4: Update Helpers for Snapshot

- [x] **RED**: Update test `apps/agents_web/test/live/sessions/helpers_test.exs`
  - Tests:
    - Existing helper functions still work (regression)
    - New `lane_status_label/1` returns human-readable lane names
    - New `lane_css_class/1` returns appropriate CSS for each lane type
- [x] **GREEN**: Update `apps/agents_web/lib/live/sessions/helpers.ex`
  - Add `lane_status_label/1`, `lane_css_class/1`
- ⏸ **REFACTOR**: Remove `derive_sticky_warm_task_ids` helper if fully superseded

### Phase 4 Validation

- ⏸ All interface tests pass
- ⏸ All infrastructure + application + domain tests still pass
- ⏸ Feature flag off: no visual or behavioral change (all 94 existing LiveView tests pass)
- ⏸ Feature flag on: new snapshot-driven UI renders correctly
- ⏸ No boundary violations (`mix boundary`)
- ⏸ Full test suite passes (`mix test`)

---

## Phase 5: Migration — Mirror, Switch, Remove Legacy

**Goal**: Gradually roll out the new orchestrator, then remove QueueManager.

**Commit point (mirror)**: "feat(agents): mirror queue state between QueueManager and QueueOrchestrator"
**Commit point (switch)**: "feat(agents): switch default queue backend to QueueOrchestrator"
**Commit point (cleanup)**: "chore(agents): remove legacy QueueManager and feature flag"

### Step 5.1: Mirror Mode

- ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/queue_mirror_test.exs`
  - Tests:
    - When mirror mode enabled, both QueueManager and QueueOrchestrator receive notifications
    - QueueOrchestrator snapshot matches QueueManager state (cross-validation)
    - Discrepancies are logged as warnings (not errors)
- ⏸ **GREEN**: Add mirror mode to Sessions facade
  - When mirror enabled: route notifications to both backends, compare snapshots
  - Log discrepancies for observability
- ⏸ **REFACTOR**: Make mirror mode zero-cost when disabled

### Step 5.2: Switch Default

- ⏸ **RED**: Update tests to verify QueueOrchestrator is the default backend
  - Tests:
    - `SessionsConfig.queue_v2_enabled?/0` defaults to true
    - All existing QueueManager integration tests pass against QueueOrchestrator
    - LiveView renders correctly with QueueOrchestrator as backend
- ⏸ **GREEN**: Update config to default `queue_v2_enabled: true`
- ⏸ **REFACTOR**: Remove mirror mode code

### Step 5.3: Remove Legacy QueueManager

- ⏸ **RED**: Verify no tests reference QueueManager directly (except deletion tests)
- ⏸ **GREEN**: Remove files:
  - `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex`
  - `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs`
  - Remove QueueManager from supervision tree
  - Remove QueueManager Registry (`Agents.Sessions.QueueRegistry` → reuse for Orchestrator)
  - Remove feature flag checks from Sessions facade
  - Remove `QueueSnapshot.to_legacy_map/1`
  - Remove legacy template branch from `index.html.heex`
  - Remove `derive_sticky_warm_task_ids` from LiveView and helpers
- ⏸ **REFACTOR**: Clean up imports, aliases, dead code across all files

### Step 5.4: Template Cleanup

- ⏸ **RED**: Verify template renders correctly without legacy conditional branches
- ⏸ **GREEN**: Remove `if @queue_v2_enabled` conditionals from template
  - Template now unconditionally uses `<.queue_lanes snapshot={@queue_snapshot}>`
  - Remove ~200 lines of inline lane partition logic
- ⏸ **REFACTOR**: Final template cleanup, ensure all data-testid attributes are preserved

### Phase 5 Validation

- ⏸ All tests pass with QueueOrchestrator as sole backend
- ⏸ No references to QueueManager remain in codebase
- ⏸ Feature flag removed from config
- ⏸ No boundary violations (`mix boundary`)
- ⏸ Full test suite passes (`mix test`)
- ⏸ Pre-commit checks pass (`mix precommit`)

---

## Pre-Commit Checkpoint (after each phase)

- ⏸ `mix format` passes
- ⏸ `mix credo` passes
- ⏸ `mix boundary` passes
- ⏸ `mix test` passes (full suite)

## Final Validation (after Phase 5)

- ⏸ `mix precommit` passes
- ⏸ `mix boundary` passes
- ⏸ Queue lane assignment is fully policy-driven and unit-testable ✓
- ⏸ Queue transitions are deterministic and emitted as canonical snapshots ✓
- ⏸ UI no longer performs lane inference; only renders snapshot ✓
- ⏸ Processing appears at bottom in bottom-up view ✓
- ⏸ Warm/concurrency rules rendered from snapshot metadata ✓
- ⏸ Retry behavior is explicit and test-covered ✓

---

## Testing Strategy

- **Total estimated tests**: ~85-95 new/updated tests
- **Distribution**:
  - Domain (Phase 1): ~35 tests (pure, async, milliseconds)
    - QueueSnapshot entity: 6 tests
    - QueueEngine policy: 15 tests
    - RetryPolicy: 8 tests
    - QueuePolicy updates: 2 tests
    - Domain events: 3 tests
    - Existing QueuePolicy regression: 8 tests (unchanged)
  - Application (Phase 2): ~15 tests (mocked, async)
    - SessionsConfig: 2 tests
    - BuildSnapshot use case: 5 tests
    - PromoteTask use case: 7 tests
    - ScheduleRetry use case: 7 tests
    - CreateTask/ResumeTask updates: 4 tests
  - Infrastructure (Phase 3): ~25 tests (with database)
    - Migration: 1 test (migration runs)
    - TaskSchema updates: 3 tests
    - TaskRepository/TaskQueries: 3 tests
    - QueueOrchestrator: 13 tests
    - QueueOrchestrator Supervisor: 3 tests
    - Sessions facade: 5 tests
  - Interface (Phase 4): ~15 tests
    - Queue lane components: 6 tests
    - LiveView snapshot integration: 5 tests
    - Template rendering: 3 tests
    - Helpers: 2 tests
  - Migration (Phase 5): ~5 tests
    - Mirror mode: 3 tests
    - Default switch: 2 tests

---

## File Change Summary

### New Files (~15)

| File | Layer | Description |
|------|-------|-------------|
| `apps/agents/lib/agents/sessions/domain/entities/queue_snapshot.ex` | Domain | QueueSnapshot struct |
| `apps/agents/lib/agents/sessions/domain/entities/lane_entry.ex` | Domain | LaneEntry struct |
| `apps/agents/lib/agents/sessions/domain/policies/queue_engine.ex` | Domain | Lane assignment + transition rules |
| `apps/agents/lib/agents/sessions/domain/policies/retry_policy.ex` | Domain | Retry/backoff/escalation policy |
| `apps/agents/lib/agents/sessions/domain/events/task_lane_changed.ex` | Domain | Lane transition event |
| `apps/agents/lib/agents/sessions/domain/events/task_retry_scheduled.ex` | Domain | Retry scheduling event |
| `apps/agents/lib/agents/sessions/domain/events/queue_snapshot_updated.ex` | Domain | Snapshot broadcast event |
| `apps/agents/lib/agents/sessions/application/behaviours/queue_orchestrator_behaviour.ex` | Application | Orchestrator interface |
| `apps/agents/lib/agents/sessions/application/use_cases/build_snapshot.ex` | Application | Snapshot construction |
| `apps/agents/lib/agents/sessions/application/use_cases/promote_task.ex` | Application | Task promotion |
| `apps/agents/lib/agents/sessions/application/use_cases/schedule_retry.ex` | Application | Retry scheduling |
| `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex` | Infrastructure | New GenServer |
| `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator_supervisor.ex` | Infrastructure | DynamicSupervisor |
| `apps/agents_web/lib/live/sessions/components/queue_lane_components.ex` | Interface | Snapshot-driven UI components |
| `apps/agents/priv/repo/migrations/*_add_retry_fields_to_sessions_tasks.exs` | Infrastructure | DB migration |

### Modified Files (~15)

| File | Layer | Change |
|------|-------|--------|
| `apps/agents/lib/agents/sessions/domain/policies/queue_policy.ex` | Domain | Add limit validation functions |
| `apps/agents/lib/agents/sessions/domain/entities/task.ex` | Domain | Add retry fields to struct |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex` | Infrastructure | Add retry columns |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex` | Infrastructure | Add retry queries |
| `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex` | Infrastructure | Add retry query functions |
| `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex` | Application | Add retry callbacks |
| `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex` | Application | Snapshot broadcast (flagged) |
| `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex` | Application | Snapshot broadcast (flagged) |
| `apps/agents/lib/agents/sessions/application/sessions_config.ex` | Application | Feature flag |
| `apps/agents/lib/agents/sessions.ex` | Application | Feature-flagged routing |
| `apps/agents_web/lib/live/sessions/index.ex` | Interface | Snapshot subscription + assigns |
| `apps/agents_web/lib/live/sessions/index.html.heex` | Interface | Snapshot-driven template |
| `apps/agents_web/lib/live/sessions/helpers.ex` | Interface | Lane display helpers |
| `apps/agents_web/lib/live/sessions/components/session_components.ex` | Interface | Minor updates |

### Deleted Files (Phase 5 only)

| File | Reason |
|------|--------|
| `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex` | Replaced by QueueOrchestrator |
| `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs` | Tests migrated to QueueOrchestrator |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Regression in queue behavior during migration | Feature flag + mirror mode for cross-validation |
| QueueOrchestrator performance differs from QueueManager | Same GenServer pattern, same Registry; benchmark in mirror mode |
| LiveView assigns shape change breaks template | Feature-flagged template branches; backward-compatible snapshot |
| Retry scheduling overwhelms the system | Exponential backoff + max retries cap + circuit breaker potential |
| Migration adds columns to hot table | Non-blocking `ALTER TABLE` with defaults; no data migration needed |
