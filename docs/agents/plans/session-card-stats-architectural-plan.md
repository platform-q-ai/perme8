# Feature: Show session duration and file change stats on sidebar cards

## App Ownership

- **Owning app (domain)**: `agents`
- **Owning app (interface)**: `agents_web`
- **Owning Repo**: `Agents.Repo`
- **Domain code path**: `apps/agents/lib/agents/sessions/`
- **Web code path**: `apps/agents_web/lib/live/sessions/`
- **Migrations path**: `apps/agents/priv/repo/migrations/`
- **Domain tests path**: `apps/agents/test/agents/sessions/`
- **Web tests path**: `apps/agents_web/test/live/sessions/`
- **BDD feature files path**: `apps/agents_web/test/features/sessions/`

## Overview

Add session-level duration and persisted file-change stats to sidebar cards so users can compare all sessions at a glance without relying on the active pane SSE connection. Duration must be live for running sessions and fixed for terminal sessions; file diff summary must survive refresh by persisting session summary data in `sessions_tasks`.

## UI Strategy

- **LiveView coverage**: 100% (duration ticking, formatting, and sidebar rendering are server-rendered LiveView concerns)
- **TypeScript needed**: None (no complex client-side algorithm, browser API wrapper, or JS library integration required)

## Affected Boundaries

- **Owning app**: `agents` (domain/infrastructure) + `agents_web` (interface)
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/sessions/session-card-stats.browser.feature`
- **Primary context**: `Agents.Sessions`
- **Dependencies**: none beyond existing `agents_web -> agents` facade calls
- **Exported schemas**: no new exports required
- **New context needed?**: No; this is an enhancement inside the existing `Agents.Sessions` bounded context

---

## Phase 1: Domain + Application (phoenix-tdd)

### Task Entity session summary support

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/domain/entities/task_test.exs`
  - Add assertions that `%Task{}` includes `:session_summary`
  - Add `from_schema/1` mapping assertion for persisted summary map `%{"files" => 3, "additions" => 42, "deletions" => 18}`
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/domain/entities/task.ex`
  - Add `session_summary: map() | nil` to type, struct, and `from_schema/1`
- [ ] ⏸ **REFACTOR**: Keep entity as pure data mapping only (no formatting/business logic)

### ResumeTask stale-summary reset policy

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/resume_task_test.exs`
  - Add assertion that resume reset clears stale `session_summary` alongside `started_at`/`completed_at`
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex`
  - Extend `reset_task_for_resume/3` attrs with `session_summary: nil`
- [ ] ⏸ **REFACTOR**: Keep reset logic centralized in `reset_task_for_resume/3`

### Sessions facade contract for sidebar stats fields

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions_test.exs`
  - Add assertions under `describe "list_sessions/2"` that each session map includes duration source fields (`started_at`, `completed_at`) and `session_summary`
- [ ] ⏸ **GREEN**: Update docs/spec in `apps/agents/lib/agents/sessions.ex`
  - Expand `list_sessions/2` return contract docs to include new fields used by interface cards
- [ ] ⏸ **REFACTOR**: Ensure facade remains thin delegation to repository/query layer

### Phase 1 Validation

- [ ] ⏸ All updated domain tests pass (`mix test apps/agents/test/agents/sessions/domain/entities/task_test.exs`)
- [ ] ⏸ All updated application/facade tests pass (`mix test apps/agents/test/agents/sessions/application/use_cases/resume_task_test.exs apps/agents/test/agents/sessions_test.exs`)
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### Migration: persist session summary

- [ ] ⏸ **GREEN**: Create `apps/agents/priv/repo/migrations/[timestamp]_add_session_summary_to_sessions_tasks.exs`
  - Add nullable `:session_summary, :map` column to `sessions_tasks`

### Task schema + fixtures support

- [ ] ⏸ **RED**: Update tests
  - `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_test.exs` for cast/acceptance of `session_summary`
  - `apps/agents/test/support/fixtures/sessions_fixtures.ex` fixture coverage for optional `session_summary`
- [ ] ⏸ **GREEN**: Update implementation
  - `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex` to add field/type + cast in `changeset/2` and `status_changeset/2`
  - `apps/agents/test/support/fixtures/sessions_fixtures.ex` to support inserting summary data
- [ ] ⏸ **REFACTOR**: Keep schema focused on cast/validation only

### TaskRunner persistence of `session.updated` summary

- [ ] ⏸ **RED**: Update `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs`
  - Add scenario asserting `session.updated` causes repository update with `session_summary`
  - Add guard scenario that non-map/empty summary payloads do not crash or write invalid data
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Handle `"session.updated"` events in `handle_sdk_event/2`
  - Extract `info.summary` map and persist via `update_task_status/2`
  - Persist only when summary payload is present and changed to reduce write churn
- [ ] ⏸ **REFACTOR**: Keep event parser logic private and isolated from unrelated SSE handlers

### Session aggregate query (`sessions_for_user/1`) adds duration + summary

- [ ] ⏸ **RED**: Update `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs`
  - Add assertions for `started_at` = `min(started_at)` per `container_id`
  - Add assertions for `completed_at` = `max(completed_at)` per `container_id`
  - Add assertions for `session_summary` from latest task in session (`array_agg ... ORDER BY inserted_at DESC`)
  - Add running-session case where `completed_at` is nil but `started_at` exists
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex`
  - Extend select map with grouped duration source fields and latest summary payload
- [ ] ⏸ **REFACTOR**: Keep query composable and deterministic ordering by `inserted_at`

### Repository pass-through and regression coverage

- [ ] ⏸ **RED**: Update `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs`
  - Assert `list_sessions_for_user/2` returns new fields populated from query
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex` only if shape adaptation is needed
- [ ] ⏸ **REFACTOR**: Preserve thin repository wrapper pattern

### Duration formatting helpers (UI)

- [ ] ⏸ **RED**: Extend `apps/agents_web/test/live/sessions/helpers_test.exs`
  - Add `format_duration/2` tests for examples: `12m 30s`, `1h 5m`, `2d 3h`
  - Add running vs terminal behavior tests (uses injected `now` for deterministic assertions)
  - Add file stats formatter tests (e.g., `3 files +42 -18`, nil summary hidden)
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/helpers.ex`
  - Add `format_duration(started_at, completed_at, now \\ DateTime.utc_now())`
  - Add helper for rendering/presence checks of summary stats
- [ ] ⏸ **REFACTOR**: Keep helpers pure and side-effect free

### LiveView timer for running session duration tick

- [ ] ⏸ **RED**: Update `apps/agents_web/test/live/sessions/index_test.exs`
  - Add test that running card duration changes after `:tick_session_durations` message
  - Add test that terminal card duration remains stable
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`
  - Add periodic tick (`:tick_session_durations`) and assign (`:duration_now`) for rendering
  - Start timer only when sessions include active/running status; reschedule while needed
- [ ] ⏸ **REFACTOR**: Keep tick handler lightweight (no DB calls; pure assign update)

### Sidebar card template updates

- [ ] ⏸ **RED**: Update `apps/agents_web/test/live/sessions/index_test.exs`
  - Assert session cards render duration text
  - Assert session cards render file stats text when summary exists
  - Assert cards omit file stats block when summary missing
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.html.heex`
  - Add duration row/value to each card
  - Add file change summary row/value (`files +additions -deletions`) using helper output
  - Keep existing card structure and style conventions
- [ ] ⏸ **REFACTOR**: Keep template logic minimal; delegate calculations to helpers

### Event processor alignment for persisted summary

- [ ] ⏸ **RED**: Update `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - Verify `session.updated` still updates active pane summary while DB-backed sidebar uses persisted session data after reload
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/event_processor.ex` only if event shape normalization is required
- [ ] ⏸ **REFACTOR**: Avoid duplicating formatting between event processor and helpers

### BDD feature specification for acceptance criteria

- [ ] ⏸ **RED**: Add/extend acceptance scenarios in `apps/agents_web/test/features/sessions/session-card-stats.browser.feature`
  - Running session card shows live-updating duration
  - Terminal session card shows fixed total duration
  - Card shows file stats when available
  - File stats survive page reload
- [ ] ⏸ **GREEN**: Implement any missing test IDs/selectors in `apps/agents_web/lib/live/sessions/index.html.heex`
- [ ] ⏸ **REFACTOR**: Keep feature language user-facing and implementation-agnostic

### Phase 2 Validation

- [ ] ⏸ Infrastructure tests pass (`apps/agents` targeted suites)
- [ ] ⏸ Interface tests pass (`apps/agents_web` targeted suites)
- [ ] ⏸ Migration runs cleanly (`mix ecto.migrate`)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full tests pass (`mix test`)

### Pre-commit Checkpoint (required)

- [ ] ⏸ Run `mix precommit`
- [ ] ⏸ Run `mix boundary`

---

## Testing Strategy

- **Total estimated tests**: 24
- **Distribution**: Domain 2, Application 3, Infrastructure 11, Interface 8
- **Key emphasis**:
  - Query-level correctness for session aggregates (`min(started_at)`, `max(completed_at)`, latest `session_summary`)
  - Deterministic duration formatting/unit tests (pure helper tests)
  - LiveView behavior for ticking durations and sidebar rendering
  - Persistence regression that confirms file stats survive reconnect/page reload
