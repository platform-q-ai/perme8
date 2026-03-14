# Feature: #426 — Redesign session warming: keep containers running + fix v2 QueueOrchestrator + remove v1 QueueManager

## Overview

This ticket redesigns the warming system to keep containers running through the queue (instead of the v1 start+stop pattern), fixes two critical bugs in the v2 QueueOrchestrator (resume_prompt extraction and runner opts passthrough), migrates all queue orchestration to v2, and removes the v1 QueueManager entirely.

### Three promotion paths after this change:
1. **New warm session**: Container already running from warming phase → git pull → auth → create session → SSE → prompt
2. **Existing warm session (resume)**: Container restarted during warming, session_id exists → SSE subscribe → prompt only
3. **Cold session**: No warming → full cold path: docker run → health check → git pull → auth → create session → SSE → prompt

## UI Strategy
- **LiveView coverage**: 100% — all changes are server-side Elixir
- **TypeScript needed**: None

## Affected Boundaries
- **Owning app**: `agents` (domain/infrastructure) and `agents_web` (interface)
- **Repo**: `Agents.Repo`
- **Migrations**: None required (no schema changes — container_id and container_port fields already exist on TaskSchema)
- **Feature files**: N/A (infrastructure changes, no new user-facing features)
- **Primary context**: `Agents.Sessions` (Sessions bounded context)
- **Dependencies**: `Perme8.Events` (domain event infrastructure)
- **Exported schemas**: None new
- **New context needed?**: No — all changes within existing Sessions context

## Design Notes

### Dead code preservation
`notify_question_asked/2` and `notify_feedback_provided/2` are defined on the QueueOrchestrator behaviour but never called from anywhere in the codebase. They are preserved in QueueOrchestrator for future wiring.

### Warming implementation details
- The `:warm_top_queued` handler uses `Task.async` for each container start — container warming is non-blocking
- Containers are kept running (NOT stopped after start like v1)
- Both `container_id` AND `container_port` are saved on queued tasks after warming
- When a task with an existing `container_id` + `session_id` is re-queued (e.g., after `notify_feedback_provided`), the existing container is stopped first

### TaskRunner warm path
- `:restart_prewarmed_container` should check container status first — skip `docker restart` if already running, just discover port
- For already-warmed containers, skip or shorten health check via `already_healthy: true` flag

---

## Phase 1: Fix QueueOrchestrator Bugs (phoenix-tdd)

**Goal**: Fix the two critical bugs that prevent resume and prewarmed container information from reaching TaskRunner. This is a prerequisite for all subsequent phases.

### 1.1 Bug Fix: `promote_single_task/3` — extract resume_prompt and clear it

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - `describe "promote_single_task resume_prompt handling"`
  - Test: "extracts resume_prompt from pending_question and clears it during promotion"
    - Create a queued task with `pending_question: %{"resume_prompt" => "continue here"}`
    - Set up a task_runner_starter mock that captures opts
    - Trigger promotion via `notify_task_completed/2` (frees a slot)
    - Assert: task_runner_starter received opts containing `resume: true`, `prompt_instruction: "continue here"`, `container_id`, `session_id`
    - Assert: promoted task in DB has `pending_question` with `resume_prompt` key removed
  - Test: "passes empty opts when no resume_prompt present"
    - Create a queued task with `pending_question: nil` and no container_id
    - Trigger promotion
    - Assert: task_runner_starter received opts `[]` (cold start)

- [ ] ⏸ **GREEN**: Implement resume_prompt extraction in `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`
  - Add `queued_resume_prompt/1` private function (extract from `pending_question["resume_prompt"]`)
  - Add `clear_resume_prompt/1` private function (remove `resume_prompt` key from pending_question map)
  - Modify `promote_single_task/3` to:
    1. Call `queued_resume_prompt(task.pending_question)` before the update
    2. Include `pending_question: clear_resume_prompt(task.pending_question)` in the update attrs
    3. Pass `resume_prompt` to `maybe_start_runner/3` (new arity)

- [ ] ⏸ **REFACTOR**: Extract shared resume_prompt helpers if they duplicate v1 logic exactly

### 1.2 Bug Fix: `maybe_start_runner/2` — pass runner opts based on task state

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - `describe "maybe_start_runner runner opts"`
  - Test: "passes resume opts when task has container_id + session_id + resume_prompt"
    - Create a queued task with `container_id: "cid-1"`, `session_id: "sid-1"`, `pending_question: %{"resume_prompt" => "try again"}`
    - Set up a mock task_runner_starter that captures `{task_id, opts}`
    - Trigger promotion
    - Assert: opts == `[resume: true, instruction: task.instruction, prompt_instruction: "try again", container_id: "cid-1", session_id: "sid-1"]`
  - Test: "passes prewarmed opts when task has container_id but no session_id"
    - Create a queued task with `container_id: "cid-2"`, `session_id: nil`
    - Trigger promotion
    - Assert: opts == `[prewarmed_container_id: "cid-2", fresh_warm_container: true]`
  - Test: "passes empty opts for cold start task"
    - Create a queued task with `container_id: nil`, `session_id: nil`
    - Trigger promotion
    - Assert: opts == `[]`

- [ ] ⏸ **GREEN**: Implement `runner_opts_for/2` and update `maybe_start_runner/3` in `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`
  - Add `runner_opts_for/2` private function matching the three patterns (resume, prewarmed, cold) — port from v1's implementation
  - Change `maybe_start_runner/2` → `maybe_start_runner/3` accepting `resume_prompt` as third arg
  - Replace hardcoded `[]` with `runner_opts_for(task, resume_prompt)` call

- [ ] ⏸ **REFACTOR**: Ensure runner_opts_for pattern matches are clean and well-documented

### Phase 1 Validation
- [ ] All existing QueueOrchestrator tests pass (no regressions)
- [ ] New bug-fix tests pass
- [ ] `mix test apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs` green
- [ ] No boundary violations (`mix boundary`)

---

## Phase 2: Implement Warming in QueueOrchestrator (phoenix-tdd)

**Goal**: Replace the no-op `:warm_top_queued` handler with real container warming that keeps containers running (not start+stop).

### 2.1 Warming handler: start containers for cold queued tasks

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - `describe "warm_top_queued handler"`
  - Test: "starts containers for cold queued tasks up to warm_cache_limit"
    - Create 3 cold queued tasks (no container_id), set `warm_cache_limit: 2`
    - Set up a mock container_provider that returns `{:ok, %{container_id: "warm-N", port: 4000+N}}` for each start
    - Start orchestrator, trigger `:warm_top_queued` via `notify_task_queued`
    - Assert: first 2 tasks in DB now have `container_id` and `container_port` set
    - Assert: third task still has `container_id: nil`
    - Assert: `container_provider.stop` was NOT called (containers stay running)
  - Test: "skips tasks that already have a running container"
    - Create a queued task with `container_id: "existing"`, mock container_provider.status → `:running`
    - Trigger warming
    - Assert: container_provider.start NOT called for this task
  - Test: "re-warms tasks whose container is not_found"
    - Create a queued task with `container_id: "gone"`, mock container_provider.status → `:not_found`
    - Trigger warming
    - Assert: container_provider.start called, task updated with new container_id + port
  - Test: "does nothing when warm_cache_limit is 0"
    - Create cold queued tasks, set `warm_cache_limit: 0`
    - Trigger warming
    - Assert: container_provider.start NOT called

- [ ] ⏸ **GREEN**: Implement warming handler in `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`
  - Replace the no-op `:warm_top_queued` handler with:
    ```elixir
    def handle_info(:warm_top_queued, state) do
      state = %{state | warmup_scheduled: false}
      warm_top_queued_tasks(state)
      state = %{state | warming_task_ids: MapSet.new()}
      broadcast_snapshot(state)
      {:noreply, state}
    end
    ```
  - Implement `warm_top_queued_tasks/1`:
    - Build snapshot, take cold tasks up to `warm_cache_limit`
    - For each task, call `maybe_warm_task/2`
  - Implement `maybe_warm_task/2`:
    - If `container_id: nil` → call `warm_task_container/2`
    - If has container_id → check status via `container_provider.status`:
      - `:running` → skip (already warm)
      - `:stopped` → call `container_provider.restart` and save port
      - `:not_found` → call `warm_task_container/2` (start fresh)
  - Implement `warm_task_container/2`:
    - Call `container_provider.start(image, [])` → get `{container_id, port}`
    - Save BOTH `container_id` AND `container_port` on the task (key difference from v1 which only saved container_id)
    - Do NOT stop the container (key difference from v1's start+stop pattern)
    - Broadcast lifecycle transition for the warmed task

- [ ] ⏸ **REFACTOR**: Clean up, add Logger.debug calls for observability

### 2.2 Stop containers when tasks with existing container_id+session_id are re-queued

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - `describe "re-queued tasks with existing containers"`
  - Test: "stops container when task with container_id+session_id transitions to queued via feedback"
    - Create a task with status "awaiting_feedback", `container_id: "old-cid"`, `session_id: "old-sid"`
    - Set up mock container_provider that tracks stop calls
    - Call `notify_feedback_provided/2` (which re-queues the task)
    - Assert: `container_provider.stop("old-cid")` was called
    - Note: The re-queued task should clear container_port (it will get a new one from warming)

- [ ] ⏸ **GREEN**: Update `maybe_requeue_after_feedback/2` in `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`
  - Before re-queuing a task that has both container_id and session_id, call `state.container_provider.stop(task.container_id)`
  - Clear `container_port` when re-queuing (the warming cycle will assign a new one)

- [ ] ⏸ **REFACTOR**: Extract container cleanup into a reusable helper

### 2.3 Warming uses Task.async for non-blocking container starts

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - Test: "warming starts containers asynchronously without blocking the GenServer"
    - Create a cold queued task
    - Set up a slow container_provider.start (Process.sleep before returning)
    - Trigger warming
    - Assert: GenServer remains responsive during warming (can still handle :get_snapshot)
    - Assert: after the async task completes, the task in DB has container_id + port

- [ ] ⏸ **GREEN**: Wrap container warming in `Task.async` within the `:warm_top_queued` handler
  - Each `maybe_warm_task/2` call starts a `Task.async` that:
    1. Starts the container
    2. Sends `{:warm_task_result, task_id, {:ok, container_id, port}}` back to the orchestrator
  - Add `handle_info({:warm_task_result, task_id, result}, state)` handler to save container info to DB

- [ ] ⏸ **REFACTOR**: Add error handling for failed warm tasks, ensure warming_task_ids is properly tracked

### Phase 2 Validation
- [ ] All existing tests pass (no regressions)
- [ ] New warming tests pass
- [ ] `mix test apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs` green
- [ ] No boundary violations

---

## Phase 3: Update TaskRunner for Warm Paths (phoenix-tdd)

**Goal**: Update TaskRunner to handle the "already running and healthy" warm container scenario — skip docker restart and health check where possible.

### 3.1 `:restart_prewarmed_container` — skip restart if container already running

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - `describe "prewarmed container already running"`
  - Test: "skips docker restart when container is already running and has port"
    - Create a task, start TaskRunner with opts: `prewarmed_container_id: "warm-cid"`, `already_healthy: true`, `container_port: 4001`
    - Use a mock container_provider that tracks restart calls and status returns `:running`
    - Assert: container_provider.restart NOT called
    - Assert: TaskRunner proceeds to `:prepare_fresh_start` with the existing port
  - Test: "restarts container when status is :stopped"
    - Same setup but container_provider.status returns `:stopped`
    - Assert: container_provider.restart IS called
    - Assert: TaskRunner proceeds normally with new port

- [ ] ⏸ **GREEN**: Update `:restart_prewarmed_container` handler in `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Before calling `container_provider.restart`, check `container_provider.status(container_id)`
  - If `:running`, use the existing `container_port` from opts and skip restart
  - If `:stopped` or other, proceed with restart as before
  - Accept `container_port` in opts for the "already running" case

- [ ] ⏸ **REFACTOR**: Clean up conditionals

### 3.2 Skip health check for already-healthy containers

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - `describe "already_healthy flag"`
  - Test: "skips health check and goes directly to prepare_fresh_start when already_healthy: true"
    - Start TaskRunner with `already_healthy: true`, mock opencode_client.health never called
    - Assert: proceeds directly to `:prepare_fresh_start`
  - Test: "performs normal health check when already_healthy: false"
    - Start TaskRunner without the flag
    - Assert: health check is performed normally

- [ ] ⏸ **GREEN**: Update TaskRunner in `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Add `already_healthy` field to the TaskRunner struct (default: `false`)
  - Read from opts during init: `already_healthy: Keyword.get(opts, :already_healthy, false)`
  - In the warm path, if `already_healthy` is true, skip health check — send `:prepare_fresh_start` directly

- [ ] ⏸ **REFACTOR**: Ensure the flag is properly reset after use (one-shot)

### 3.3 Pass container_port through runner opts

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - Test: "accepts container_port from opts for prewarmed containers"
    - Start TaskRunner with `prewarmed_container_id: "cid"`, `container_port: 4001`, `already_healthy: true`
    - Assert: TaskRunner uses port 4001 without calling restart or health check

- [ ] ⏸ **GREEN**: Update `initialize_lifecycle/7` and `maybe_start_from_prewarmed/2` in TaskRunner
  - Accept `container_port` from opts
  - When container is already running with a known port, set both `container_id` and `container_port` on state

- [ ] ⏸ **REFACTOR**: Update runner_opts_for in QueueOrchestrator to include `container_port` and `already_healthy: true` when task has both `container_id` and `container_port`

### Phase 3 Validation
- [ ] All existing TaskRunner tests pass
- [ ] New warm path tests pass
- [ ] `mix test apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` green
- [ ] Integration: manually verify a warm promotion path works end-to-end
- [ ] No boundary violations

---

## Phase 4: Remove v1 QueueManager (phoenix-tdd)

**Goal**: Delete v1 modules (QueueManager, QueueManagerSupervisor, QueueMirror), remove all v1/v2 branching logic, and simplify the Sessions facade.

### 4.1 Remove v1/v2 branching in Sessions facade

- [ ] ⏸ **RED**: Update existing tests in `apps/agents/test/agents/sessions_test.exs`
  - Change all references from `queue_manager:` / `queue_manager_supervisor:` opts keys to `queue_orchestrator:` / `queue_orchestrator_supervisor:` keys
  - Verify tests fail because the old opts keys are no longer recognized
  - Add test: "always uses QueueOrchestrator without feature flag check"
    - Verify `get_queue_state/1` returns a QueueSnapshot-derived map regardless of config

- [ ] ⏸ **GREEN**: Simplify `apps/agents/lib/agents/sessions.ex`
  - Remove `alias Agents.Sessions.Infrastructure.QueueManager`
  - Remove `alias Agents.Sessions.Infrastructure.QueueMirror`
  - Remove `alias Agents.Sessions.Infrastructure.QueueManagerSupervisor`
  - Remove `queue_module/0` — replace all calls with `QueueOrchestrator`
  - Remove `queue_supervisor_module/0` — replace all calls with `QueueOrchestratorSupervisor`
  - Remove `queue_backend_modules/1` — inline `QueueOrchestratorSupervisor` and `QueueOrchestrator` directly (with override from opts via `queue_orchestrator_supervisor` and `queue_orchestrator` keys)
  - Remove `queue_backend_opts/1` — inline `Keyword.get(opts, :queue_orchestrator_opts, default_queue_backend_opts())`
  - Remove both `maybe_mirror_queue_state/1` calls in `set_concurrency_limit/2` and `notify_task_terminal_status/4`
  - Remove `rate_limited_mirror_warning/2`
  - Remove the `if not SessionsConfig.queue_v2_enabled?()` guards
  - Simplify `ensure_queue_backend_started/1` to always use `QueueOrchestratorSupervisor`
  - Simplify `default_queue_checker/1` to always use `QueueOrchestrator`

- [ ] ⏸ **REFACTOR**: Ensure the facade is clean and under 400 lines

### 4.2 Remove config flags from SessionsConfig

- [ ] ⏸ **RED**: Update tests in `apps/agents/test/agents/sessions/application/sessions_config_test.exs`
  - Remove tests for `queue_v2_enabled?/0`
  - Remove tests for `queue_mirror_enabled?/0`
  - Add test verifying these functions no longer exist

- [ ] ⏸ **GREEN**: Remove from `apps/agents/lib/agents/sessions/application/sessions_config.ex`
  - Delete `queue_v2_enabled?/0` function
  - Delete `queue_mirror_enabled?/0` function

- [ ] ⏸ **REFACTOR**: Clean up any leftover references to these functions

### 4.3 Remove QueueManagerSupervisor from OTP supervision tree

- [ ] ⏸ **RED**: Verify the application starts without QueueManagerSupervisor
  - Write a simple assertion test that `Agents.Supervisor` children do not include QueueManagerSupervisor (or just verify existing tests pass)

- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/otp_app.ex`
  - Remove `alias Agents.Sessions.Infrastructure.QueueManagerSupervisor`
  - Remove `QueueManagerSupervisor` from the children list
  - Remove the comment about "Both queue supervisors run unconditionally..."

- [ ] ⏸ **REFACTOR**: Update the comment to reflect v2-only architecture

### 4.4 Remove v1 boundary exports

- [ ] ⏸ **RED**: Verify compilation succeeds without the exports (will succeed once modules are deleted)

- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure.ex`
  - Remove from exports: `QueueManager`, `QueueManagerSupervisor`, `QueueMirror`

- [ ] ⏸ **REFACTOR**: Update moduledoc to remove v1 references

### 4.5 Delete v1 modules

- [ ] ⏸ **RED**: Verify all tests pass without these modules

- [ ] ⏸ **GREEN**: Delete the following files:
  - `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex`
  - `apps/agents/lib/agents/sessions/infrastructure/queue_manager_supervisor.ex`
  - `apps/agents/lib/agents/sessions/infrastructure/queue_mirror.ex`

- [ ] ⏸ **REFACTOR**: Grep codebase for any remaining references to QueueManager/QueueMirror

### 4.6 Delete v1 test files

- [ ] ⏸ **GREEN**: Delete the following test files:
  - `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs`
  - `apps/agents/test/agents/sessions/infrastructure/queue_mirror_test.exs`
  - `apps/agents/test/agents/sessions/queue_routing_test.exs`

### Phase 4 Validation
- [ ] Application starts successfully
- [ ] All remaining agents tests pass
- [ ] `mix test apps/agents` green
- [ ] No compilation warnings for missing modules
- [ ] No boundary violations (`mix boundary`)
- [ ] `grep -r "QueueManager" apps/agents/ --include="*.ex" --include="*.exs"` returns no results (except maybe comments)
- [ ] `grep -r "QueueMirror" apps/agents/ --include="*.ex" --include="*.exs"` returns no results
- [ ] `grep -r "queue_v2_enabled" apps/agents/ --include="*.ex" --include="*.exs"` returns no results
- [ ] `grep -r "queue_mirror_enabled" apps/agents/ --include="*.ex" --include="*.exs"` returns no results

---

## Phase 5: Update LiveView — Remove v1/v2 Branching (phoenix-tdd)

**Goal**: Simplify the dashboard LiveView to always use the v2 snapshot path, removing all conditional rendering and v1 handlers.

### 5.1 Remove `queue_v2_enabled` assign and always use snapshot path

- [ ] ⏸ **RED**: Update tests in `apps/agents_web/test/agents_web/live/dashboard/` (any tests referencing `queue_v2_enabled`)
  - Remove any test setup that sets `queue_v2_enabled: false`
  - Add test: "mount always assigns queue_snapshot from load_queue_state"

- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.ex`
  - Simplify mount to always use the snapshot path:
    ```elixir
    queue_snapshot = load_queue_state(user.id)
    queue_state = QueueSnapshot.to_legacy_map(queue_snapshot)
    ```
  - Remove the `{queue_v2_enabled, queue_snapshot, queue_state} = case ...` block
  - Remove `assign(:queue_v2_enabled, queue_v2_enabled)` — delete this assign entirely
  - Always assign `queue_snapshot`

- [ ] ⏸ **REFACTOR**: Remove any dead code paths

### 5.2 Simplify template — always render snapshot-based queue panel

- [ ] ⏸ **RED**: Write test verifying the snapshot queue components always render
  - Test that `.queue_metadata` and `.queue_lanes` are always rendered (not conditional)

- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.html.heex`
  - Replace the conditional block (lines 689-694):
    ```heex
    <%= if @queue_v2_enabled and @queue_snapshot do %>
      <.queue_metadata snapshot={@queue_snapshot} />
      <.queue_lanes snapshot={@queue_snapshot} active_container_id={@active_container_id} />
    <% else %>
      <.queue_panel queue_state={@queue_state} user_id={@current_scope.user.id} />
    <% end %>
    ```
    With the unconditional snapshot path:
    ```heex
    <%= if @queue_snapshot do %>
      <.queue_metadata snapshot={@queue_snapshot} />
      <.queue_lanes snapshot={@queue_snapshot} active_container_id={@active_container_id} />
    <% end %>
    ```

- [ ] ⏸ **REFACTOR**: Remove any unused components/imports related to `queue_panel`

### 5.3 Remove `:queue_updated` handler

- [ ] ⏸ **RED**: Verify no code sends `:queue_updated` messages after v1 removal

- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.ex`
  - Remove the `handle_info({:queue_updated, user_id, queue_state}, socket)` clause (line 344)
  - Remove `PubSubHandlers.queue_updated/3` delegation

- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/pub_sub_handlers.ex`
  - Remove the `queue_updated/3` function (lines 401-418)

- [ ] ⏸ **REFACTOR**: Verify no dead code remains

### 5.4 Simplify `load_queue_state/1` in session_data_helpers

- [ ] ⏸ **RED**: Test that `load_queue_state/1` always returns a QueueSnapshot

- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/session_data_helpers.ex`
  - Simplify `load_queue_state/1` — it now always returns a QueueSnapshot (since `Sessions.get_queue_state/1` will be updated to return snapshots)
  - OR: keep the catch-all fallback for safety but remove the v1/v2 case match

- [ ] ⏸ **REFACTOR**: Clean up `default_queue_state/0` — may still be needed as a fallback but should produce a QueueSnapshot-compatible structure

### Phase 5 Validation
- [ ] All agents_web dashboard tests pass
- [ ] Queue panel renders correctly with snapshot data
- [ ] No references to `queue_v2_enabled` in agents_web code
- [ ] No references to `:queue_updated` in agents_web code
- [ ] `mix test apps/agents_web` green (excluding pre-existing Docker :enoent failure)

---

## Pre-Commit Checkpoint

After all 5 phases:

- [ ] `mix precommit` passes
- [ ] `mix boundary` shows no violations
- [ ] `mix test apps/agents` — all tests pass
- [ ] `mix test apps/agents_web` — all tests pass (excluding pre-existing failure)
- [ ] Full `mix test` green
- [ ] Grep verification:
  - [ ] No references to `QueueManager` (module) in production code
  - [ ] No references to `QueueMirror` in production code
  - [ ] No references to `queue_v2_enabled` in production code
  - [ ] No references to `queue_mirror_enabled` in production code

---

## Testing Strategy

### Total estimated tests: ~18-22 new tests

| Layer | Area | New Tests | Modified Tests |
|-------|------|-----------|----------------|
| Infrastructure | QueueOrchestrator bug fixes | 5 | 0 |
| Infrastructure | QueueOrchestrator warming | 5 | 0 |
| Infrastructure | TaskRunner warm paths | 4 | 0 |
| Application | SessionsConfig | 0 | 2 (removed) |
| Facade | Sessions | 0 | ~5 (opts key changes) |
| Interface | Dashboard LiveView | 2-3 | ~3 (v1 removal) |

### Test Distribution:
- **Domain**: 0 (no new domain logic — policies unchanged)
- **Application**: 2 removed (config flag tests)
- **Infrastructure**: ~14 new (orchestrator + task runner)
- **Interface**: ~3-5 modified (dashboard)

### Deleted Tests: ~10
- `queue_manager_test.exs` (entire file)
- `queue_mirror_test.exs` (entire file)
- `queue_routing_test.exs` (entire file)

### Regression Baseline:
- 106 existing agents tests (queue_orchestrator, task_runner, sessions, sessions_config)
- 7 queue_routing + mirror tests (will be deleted)
- 138/139 agents_web dashboard tests (1 pre-existing Docker :enoent failure)

### Domain Event Testing:
All QueueOrchestrator tests that trigger promotion or warming must use `TestEventBus` injection:
```elixir
start_orchestrator!(user.id,
  event_bus: Perme8.Events.TestEventBus,
  task_runner_starter: fn _task_id, _opts -> {:ok, self()} end
)
```

---

## Implementation Notes for Executing Agent

### Key patterns to follow from existing code:

1. **QueueOrchestrator test pattern** (from existing `queue_orchestrator_test.exs`):
   - Use `start_supervised!({QueueOrchestrator, opts})` with injected deps
   - Use `create_task/2` helper for setting up DB fixtures
   - Subscribe to PubSub topics before triggering actions
   - Assert on PubSub messages AND DB state

2. **TaskRunner test pattern** (from existing `task_runner_test.exs`):
   - Use `StubTaskRepo`, `StubEventBus`, `StubOpencode` for DI
   - Use `common_opts/1` to merge overrides
   - Test via message passing (`send/2`) to the GenServer

3. **Container provider mock pattern**:
   - The container_provider is injected via opts
   - Use a module that tracks calls (e.g., `Agent` to accumulate call history)
   - Or use simple functions that return predetermined results

4. **v1 warming reference** (from `queue_manager.ex` lines 590-649):
   - `warm_top_queued_tasks/1`: Lists queued, takes `warm_target_count`, calls `maybe_warm_task`
   - `maybe_warm_task/2`: Checks container_id presence, calls status check or start
   - `warm_task_container/2`: Starts container, saves container_id, STOPS container (v1 pattern — we change this)

5. **v1 `runner_opts_for` reference** (from `queue_manager.ex` lines 396-420):
   - Three clauses: resume (cid+sid+prompt), prewarmed (cid, no sid), cold (default)
   - This exact pattern should be ported to QueueOrchestrator

### Files changed summary:

| File | Action |
|------|--------|
| `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex` | Modify (bug fixes + warming) |
| `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex` | Modify (warm path updates) |
| `apps/agents/lib/agents/sessions.ex` | Modify (remove v1 branching) |
| `apps/agents/lib/agents/sessions/application/sessions_config.ex` | Modify (remove config flags) |
| `apps/agents/lib/agents/otp_app.ex` | Modify (remove QueueManagerSupervisor) |
| `apps/agents/lib/agents/sessions/infrastructure.ex` | Modify (remove v1 exports) |
| `apps/agents/lib/agents/sessions/infrastructure/queue_manager.ex` | **DELETE** |
| `apps/agents/lib/agents/sessions/infrastructure/queue_manager_supervisor.ex` | **DELETE** |
| `apps/agents/lib/agents/sessions/infrastructure/queue_mirror.ex` | **DELETE** |
| `apps/agents_web/lib/live/dashboard/index.ex` | Modify (remove v1 branching) |
| `apps/agents_web/lib/live/dashboard/index.html.heex` | Modify (remove conditional) |
| `apps/agents_web/lib/live/dashboard/pub_sub_handlers.ex` | Modify (remove queue_updated) |
| `apps/agents_web/lib/live/dashboard/session_data_helpers.ex` | Modify (simplify load_queue_state) |
| `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs` | Modify (add tests) |
| `apps/agents/test/agents/sessions_test.exs` | Modify (update opts keys) |
| `apps/agents/test/agents/sessions/application/sessions_config_test.exs` | Modify (remove tests) |
| `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` | Modify (add tests) |
| `apps/agents/test/agents/sessions/infrastructure/queue_manager_test.exs` | **DELETE** |
| `apps/agents/test/agents/sessions/infrastructure/queue_mirror_test.exs` | **DELETE** |
| `apps/agents/test/agents/sessions/queue_routing_test.exs` | **DELETE** |
